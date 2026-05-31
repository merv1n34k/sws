import AppKit

/// Concrete menu-bar widgets backed by SystemStats / WiFiInfo /
/// NetworkInfo. Each widget is small enough to inline here.

final class CPUWidget: MenuBarWidget {
    let id = "cpu"
    let pollInterval: TimeInterval = 2
    private let sampler = SystemStats.CPUSampler()
    func render() -> MenuBarRendering {
        let pct = sampler.sample() * 100
        return .twoLines(top: "CPU", bottom: String(format: "%.0f%%", pct))
    }
}

final class RAMWidget: MenuBarWidget {
    let id = "ram"
    let pollInterval: TimeInterval = 3
    func render() -> MenuBarRendering {
        let (used, total) = SystemStats.memoryUsage()
        let usedGB = Double(used) / 1_073_741_824
        let totalGB = Double(total) / 1_073_741_824
        return .twoLines(top: "RAM", bottom: String(format: "%.1f/%.0fG", usedGB, totalGB))
    }
}

final class DiskWidget: MenuBarWidget {
    let id = "space"
    let pollInterval: TimeInterval = 30
    func render() -> MenuBarRendering {
        let (free, _) = SystemStats.diskUsage()
        return .twoLines(top: "SSD", bottom: SystemStats.humanBytes(free))
    }
}

final class NetworkWidget: MenuBarWidget {
    let id = "network"
    let pollInterval: TimeInterval = 1
    private let sampler = SystemStats.NetworkSampler()
    func render() -> MenuBarRendering {
        let (down, up) = sampler.sample()
        return .twoLines(
            top:    "↑ " + SystemStats.humanRate(up),
            bottom: "↓ " + SystemStats.humanRate(down)
        )
    }
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
