import AppKit

/// Concrete menu-bar widgets backed by SystemStats / WiFiInfo /
/// NetworkInfo. Each widget is small enough to inline here.

final class CPUWidget: MenuBarWidget {
    let id = "cpu"
    let pollInterval: TimeInterval = 2
    private let sampler = SystemStats.CPUSampler()
    private var lastValue = "—"
    func render() -> MenuBarRendering {
        let pct = sampler.sample() * 100
        lastValue = String(format: "%.0f%%", pct)
        return .twoLines(top: "CPU", bottom: lastValue)
    }
    func currentValue() -> String { lastValue }
}

final class RAMWidget: MenuBarWidget {
    let id = "ram"
    let pollInterval: TimeInterval = 3
    private var lastValue = "—"
    func render() -> MenuBarRendering {
        let (used, total) = SystemStats.memoryUsage()
        let pct = total > 0 ? Double(used) / Double(total) * 100 : 0
        lastValue = String(format: "%.0f%%", pct)
        return .twoLines(top: "RAM", bottom: lastValue)
    }
    func currentValue() -> String { lastValue }
}

final class DiskWidget: MenuBarWidget {
    let id = "space"
    let pollInterval: TimeInterval = 30
    private var lastValue = "—"
    func render() -> MenuBarRendering {
        let (free, _) = SystemStats.diskUsage()
        lastValue = SystemStats.humanBytes(free) + " free"
        return .twoLines(top: "SSD", bottom: SystemStats.humanBytes(free))
    }
    func currentValue() -> String { lastValue }
}

final class NetworkWidget: MenuBarWidget {
    let id = "network"
    let pollInterval: TimeInterval = 1
    private let sampler = SystemStats.NetworkSampler()
    private var lastValue = "—"
    func render() -> MenuBarRendering {
        let (down, up) = sampler.sample()
        lastValue = "↑ \(SystemStats.humanRate(up))   ↓ \(SystemStats.humanRate(down))"
        return .twoLines(
            top:    "↑ " + SystemStats.humanRate(up),
            bottom: "↓ " + SystemStats.humanRate(down)
        )
    }
    func currentValue() -> String { lastValue }
}

final class IPWidget: MenuBarWidget {
    let id = "ip"
    let pollInterval: TimeInterval = 60
    func render() -> MenuBarRendering {
        if let ip = NetworkInfo.shared.publicIP {
            return .twoLines(
                top:    NetworkInfo.shared.vpnLikely() ? "VPN" : "IP",
                bottom: ip
            )
        }
        NetworkInfo.shared.refreshPublicIP()
        return .twoLines(top: "IP", bottom: "…")
    }
    func currentValue() -> String { NetworkInfo.shared.publicIP ?? "…" }
}

final class WiFiWidget: MenuBarWidget {
    let id = "wifi"
    let pollInterval: TimeInterval = 5
    func render() -> MenuBarRendering {
        let snap = WiFiInfo.current()
        if let ssid = snap.ssid {
            let rssi = snap.rssi.map { "\($0)dB" } ?? ""
            return .twoLines(top: ssid, bottom: rssi)
        }
        return .twoLines(top: "Wi-Fi", bottom: "—")
    }
    func currentValue() -> String {
        let s = WiFiInfo.current()
        guard let ssid = s.ssid else { return "—" }
        return s.rssi.map { "\(ssid)  \($0) dBm" } ?? ssid
    }
}

/// Catalogue of widget ids the Status mode shows as buttons.
/// GPU was removed — without IOReport plumbing we can't show an
/// honest percentage, and a placeholder isn't worth the screen
/// real estate.
enum StatusWidgetID: String, CaseIterable {
    case space, cpu, network, ram

    var label: String {
        switch self {
        case .space:   return "Space"
        case .cpu:     return "CPU"
        case .network: return "Net"
        case .ram:     return "RAM"
        }
    }

    func makeWidget() -> MenuBarWidget {
        switch self {
        case .space:   return DiskWidget()
        case .cpu:     return CPUWidget()
        case .network: return NetworkWidget()
        case .ram:     return RAMWidget()
        }
    }
}
