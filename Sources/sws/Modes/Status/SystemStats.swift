import Foundation
import Darwin

/// Tiny system-stats readers. Each call is cheap and synchronous.
/// Used by the Status mode dashboard and the corresponding menu-bar
/// widgets.
enum SystemStats {

    // MARK: - CPU

    /// CPU usage split between user (apps) and system (kernel) since
    /// the last call. Each component is a 0–1 fraction; `total` is
    /// their sum.
    struct CPULoad {
        var user: Double
        var system: Double
        var total: Double { user + system }
    }

    /// Returns CPU usage split into user / system fractions
    /// (averaged across cores) since the last call. Stateful — needs
    /// a single owner.
    final class CPUSampler {
        private var lastTotal: UInt64 = 0
        private var lastIdle: UInt64 = 0
        private var lastUser: UInt64 = 0
        private var lastSystem: UInt64 = 0

        func sample() -> CPULoad {
            var info = host_cpu_load_info()
            var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
                }
            }
            guard result == KERN_SUCCESS else { return CPULoad(user: 0, system: 0) }
            let user   = UInt64(info.cpu_ticks.0)
            let system = UInt64(info.cpu_ticks.1)
            let idle   = UInt64(info.cpu_ticks.2)
            let nice   = UInt64(info.cpu_ticks.3)
            // Nice is user-space at low priority — count it with user.
            let total = user &+ system &+ idle &+ nice
            defer {
                lastTotal = total
                lastIdle = idle
                lastUser = user &+ nice
                lastSystem = system
            }
            let totalΔ = total &- lastTotal
            guard totalΔ > 0 else { return CPULoad(user: 0, system: 0) }
            let userΔ   = (user &+ nice) &- lastUser
            let systemΔ = system &- lastSystem
            return CPULoad(
                user: Double(userΔ) / Double(totalΔ),
                system: Double(systemΔ) / Double(totalΔ)
            )
        }
    }

    // MARK: - RAM

    /// Detailed memory breakdown. `used` matches Apple's Activity
    /// Monitor formula (wired + active + compressed).
    struct MemoryBreakdown {
        var total: UInt64
        /// App memory + wired + compressed — what Activity Monitor
        /// calls "Memory Used".
        var used: UInt64
        /// File-backed cache (inactive + speculative + purgeable) —
        /// "Cached Files" in Activity Monitor.
        var cached: UInt64
        /// Compressed memory.
        var compressed: UInt64
        /// Wired (kernel) memory.
        var wired: UInt64
        /// Swap currently committed to disk.
        var swapUsed: UInt64

        var usedFraction: Double {
            total > 0 ? Double(used) / Double(total) : 0
        }
    }

    /// Full memory breakdown — used by the menu-bar widget for the
    /// detail popover. `memoryUsage()` is kept as a thin wrapper for
    /// callers that just want used/total.
    static func memoryBreakdown() -> MemoryBreakdown {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryBreakdown(total: total, used: 0, cached: 0, compressed: 0, wired: 0, swapUsed: 0)
        }
        let pageSize = UInt64(vm_kernel_page_size)
        let wired      = UInt64(stats.wire_count) * pageSize
        let active     = UInt64(stats.active_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let inactive   = UInt64(stats.inactive_count) * pageSize
        let purgeable  = UInt64(stats.purgeable_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let used = wired + active + compressed
        let cached = inactive + speculative + purgeable
        return MemoryBreakdown(
            total: total,
            used: used,
            cached: cached,
            compressed: compressed,
            wired: wired,
            swapUsed: swapUsedBytes()
        )
    }

    /// Used / total memory in bytes (Activity-Monitor-equivalent).
    static func memoryUsage() -> (used: UInt64, total: UInt64) {
        let m = memoryBreakdown()
        return (m.used, m.total)
    }

    /// Returns bytes currently swapped to disk via sysctl vm.swapusage.
    private static func swapUsedBytes() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let rc = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        return rc == 0 ? UInt64(usage.xsu_used) : 0
    }

    // MARK: - Storage

    /// Free / total bytes on the root volume.
    static func diskUsage() -> (free: Int64, total: Int64) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            let total = Int64(values.volumeTotalCapacity ?? 0)
            return (free, total)
        }
        return (0, 0)
    }

    // MARK: - Network throughput

    final class NetworkSampler {
        private var lastBytesIn: UInt64 = 0
        private var lastBytesOut: UInt64 = 0
        private var lastTime: TimeInterval = 0

        /// Returns (down, up) in bytes per second since the last call.
        func sample() -> (downBytesPerSec: Double, upBytesPerSec: Double) {
            let now = ProcessInfo.processInfo.systemUptime
            let (bin, bout) = currentBytes()
            defer {
                lastBytesIn = bin
                lastBytesOut = bout
                lastTime = now
            }
            guard lastTime > 0 else { return (0, 0) }
            let dt = now - lastTime
            guard dt > 0 else { return (0, 0) }
            let din = Double(bin &- lastBytesIn) / dt
            let dout = Double(bout &- lastBytesOut) / dt
            return (din, dout)
        }

        private func currentBytes() -> (UInt64, UInt64) {
            var bin: UInt64 = 0
            var bout: UInt64 = 0
            var ifaddrs: UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&ifaddrs) == 0, let first = ifaddrs else { return (0, 0) }
            defer { freeifaddrs(ifaddrs) }
            var node = first
            while true {
                if let data = node.pointee.ifa_data,
                   let name = node.pointee.ifa_name {
                    let ifname = String(cString: name)
                    // Skip loopback so the number reflects real traffic.
                    if !ifname.hasPrefix("lo") && (node.pointee.ifa_flags & UInt32(IFF_UP)) != 0 {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        bin &+= UInt64(networkData.ifi_ibytes)
                        bout &+= UInt64(networkData.ifi_obytes)
                    }
                }
                guard let next = node.pointee.ifa_next else { break }
                node = next
            }
            return (bin, bout)
        }
    }

    // MARK: - Formatting helpers

    static func humanBytes(_ b: Int64) -> String {
        let kb = Double(b) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        if gb < 1024 { return String(format: "%.1f GB", gb) }
        return String(format: "%.2f TB", gb / 1024)
    }

    static func humanRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        let kb = bps / 1024
        if kb < 1024 { return String(format: "%.0f KB/s", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB/s", mb)
    }

    /// Fixed-width throughput, suitable for menu-bar widgets that
    /// must not shift width as the value changes. Always 8 chars:
    /// "  0 KB/s" / "999 KB/s" / "9.9 MB/s" / "999 MB/s".
    static func humanRateFixed(_ bps: Double) -> String {
        let kb = bps / 1024
        if kb < 1024 { return String(format: "%3d KB/s", Int(kb.rounded())) }
        let mb = kb / 1024
        if mb < 10 { return String(format: "%.1f MB/s", mb) }
        return String(format: "%3d MB/s", Int(mb.rounded()))
    }

    /// Fixed-width short byte string for menu-bar use. 6 chars:
    /// "999 KB", "9.9 MB", "999 MB", "9.9 GB", "999 GB", "9.9 TB".
    static func humanBytesShort(_ b: Int64) -> String {
        let kb = Double(b) / 1024
        if kb < 1024 { return String(format: "%3d KB", Int(kb.rounded())) }
        let mb = kb / 1024
        if mb < 10 { return String(format: "%.1f MB", mb) }
        if mb < 1024 { return String(format: "%3d MB", Int(mb.rounded())) }
        let gb = mb / 1024
        if gb < 10 { return String(format: "%.1f GB", gb) }
        if gb < 1024 { return String(format: "%3d GB", Int(gb.rounded())) }
        return String(format: "%.1f TB", gb / 1024)
    }
}
