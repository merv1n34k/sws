import AppKit

/// Concrete menu-bar widgets backed by SystemStats / WiFiInfo /
/// NetworkInfo. Each widget is small enough to inline here.
///
/// All `render()` outputs are sized through a per-widget reservation
/// width so that values changing (12% → 100%, 95 KB/s → 1.2 MB/s)
/// don't shift the rest of the menu-bar stack. The reservation is the
/// width of the worst-case value at that widget's font.

private let topFont = NSFont.systemFont(ofSize: 8, weight: .semibold)
private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

private func reserveWidth(top: String, longestBottom: String) -> CGFloat {
    let a = (top as NSString).size(withAttributes: [.font: topFont]).width
    let b = (longestBottom as NSString).size(withAttributes: [.font: valueFont]).width
    return ceil(max(a, b)) + 4
}

final class CPUWidget: MenuBarWidget {
    let id = "cpu"
    let pollInterval: TimeInterval = 2
    private let sampler = SystemStats.CPUSampler()
    private var lastValue = "  0%"
    private static let reserved = reserveWidth(top: "CPU", longestBottom: "100%")
    func render() -> MenuBarRendering {
        let pct = Int((sampler.sample() * 100).rounded())
        lastValue = String(format: "%3d%%", max(0, min(100, pct)))
        return .twoLines(top: "CPU", bottom: lastValue, minWidth: Self.reserved)
    }
    func currentValue() -> String { lastValue.trimmingCharacters(in: .whitespaces) }
}

final class RAMWidget: MenuBarWidget {
    let id = "ram"
    let pollInterval: TimeInterval = 3
    private var lastValue = "  0%"
    private static let reserved = reserveWidth(top: "RAM", longestBottom: "100%")
    func render() -> MenuBarRendering {
        let (used, total) = SystemStats.memoryUsage()
        let pct = total > 0 ? Int((Double(used) / Double(total) * 100).rounded()) : 0
        lastValue = String(format: "%3d%%", max(0, min(100, pct)))
        return .twoLines(top: "RAM", bottom: lastValue, minWidth: Self.reserved)
    }
    func currentValue() -> String { lastValue.trimmingCharacters(in: .whitespaces) }
}

final class DiskWidget: MenuBarWidget {
    let id = "space"
    let pollInterval: TimeInterval = 30
    private var lastValue = "   —"
    private static let reserved = reserveWidth(top: "SSD", longestBottom: "999 GB")
    func render() -> MenuBarRendering {
        let (free, _) = SystemStats.diskUsage()
        lastValue = SystemStats.humanBytesShort(free)
        return .twoLines(top: "SSD", bottom: lastValue, minWidth: Self.reserved)
    }
    func currentValue() -> String { lastValue.trimmingCharacters(in: .whitespaces) }
}

final class NetworkWidget: MenuBarWidget {
    let id = "network"
    let pollInterval: TimeInterval = 1
    private let sampler = SystemStats.NetworkSampler()
    private var lastDown = "  0 KB/s"
    private var lastUp = "  0 KB/s"
    private static let reserved = reserveWidth(top: "↑ 999 MB/s", longestBottom: "↓ 999 MB/s")
    func render() -> MenuBarRendering {
        let (down, up) = sampler.sample()
        lastUp = "↑ " + SystemStats.humanRateFixed(up)
        lastDown = "↓ " + SystemStats.humanRateFixed(down)
        return .twoLines(top: lastUp, bottom: lastDown, minWidth: Self.reserved)
    }
    func currentValue() -> String { "\(lastUp)  \(lastDown)" }
}

final class IPWidget: MenuBarWidget {
    let id = "ip"
    let pollInterval: TimeInterval = 60
    private static let reserved = reserveWidth(top: "VPN", longestBottom: "255.255.255.255")
    func render() -> MenuBarRendering {
        if let ip = NetworkInfo.shared.publicIP {
            return .twoLines(
                top:    NetworkInfo.shared.vpnLikely() ? "VPN" : "IP",
                bottom: ip,
                minWidth: Self.reserved
            )
        }
        NetworkInfo.shared.refreshPublicIP()
        return .twoLines(top: "IP", bottom: "…", minWidth: Self.reserved)
    }
    func currentValue() -> String { NetworkInfo.shared.publicIP ?? "…" }
}

final class WiFiWidget: MenuBarWidget {
    let id = "wifi"
    let pollInterval: TimeInterval = 5
    private static let reserved = reserveWidth(top: "Wi-Fi", longestBottom: "MyNetworkName")
    func render() -> MenuBarRendering {
        let snap = WiFiInfo.current()
        if let ssid = snap.ssid {
            let rssi = snap.rssi.map { "\($0)dB" } ?? ""
            return .twoLines(top: ssid, bottom: rssi, minWidth: Self.reserved)
        }
        return .twoLines(top: "Wi-Fi", bottom: "—", minWidth: Self.reserved)
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
