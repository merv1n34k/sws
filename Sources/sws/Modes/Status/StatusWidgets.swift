import AppKit

/// Concrete menu-bar widgets backed by SystemStats / WiFiInfo /
/// NetworkInfo. Each widget is small enough to inline here.

final class CPUWidget: MenuBarWidget {
    let id = "cpu"
    let pollInterval: TimeInterval = 2
    private let sampler = SystemStats.CPUSampler()
    func render() -> MenuBarRendering {
        let pct = sampler.sample() * 100
        return .text(String(format: "CPU %.0f%%", pct))
    }
}

final class RAMWidget: MenuBarWidget {
    let id = "ram"
    let pollInterval: TimeInterval = 3
    func render() -> MenuBarRendering {
        let (used, total) = SystemStats.memoryUsage()
        let usedGB = Double(used) / 1_073_741_824
        let totalGB = Double(total) / 1_073_741_824
        return .text(String(format: "RAM %.1f/%.0fG", usedGB, totalGB))
    }
}

final class DiskWidget: MenuBarWidget {
    let id = "space"
    let pollInterval: TimeInterval = 30
    func render() -> MenuBarRendering {
        let (free, _) = SystemStats.diskUsage()
        return .text("Disk " + SystemStats.humanBytes(free))
    }
}

/// Two stacked lines, upload over download — fits in the menu bar
/// at 9pt with tight line height.
final class NetworkWidget: MenuBarWidget {
    let id = "network"
    let pollInterval: TimeInterval = 1
    private let sampler = SystemStats.NetworkSampler()

    func render() -> MenuBarRendering {
        let (down, up) = sampler.sample()
        let upStr   = "↑ " + SystemStats.humanRate(up)
        let downStr = "↓ " + SystemStats.humanRate(down)

        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.lineSpacing = 0
        style.maximumLineHeight = 9
        style.minimumLineHeight = 9
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .paragraphStyle: style,
            .foregroundColor: NSColor.labelColor,
        ]
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: upStr + "\n", attributes: attrs))
        attr.append(NSAttributedString(string: downStr, attributes: attrs))
        return .attributed(attr)
    }
}

final class IPWidget: MenuBarWidget {
    let id = "ip"
    let pollInterval: TimeInterval = 60
    func render() -> MenuBarRendering {
        if let ip = NetworkInfo.shared.publicIP {
            return .text(NetworkInfo.shared.vpnLikely() ? "VPN \(ip)" : "IP \(ip)")
        }
        // Trigger an async refresh; next tick will pick it up.
        NetworkInfo.shared.refreshPublicIP()
        return .text("IP …")
    }
}

final class WiFiWidget: MenuBarWidget {
    let id = "wifi"
    let pollInterval: TimeInterval = 5
    func render() -> MenuBarRendering {
        let snap = WiFiInfo.current()
        if let ssid = snap.ssid, let rssi = snap.rssi {
            return .text("\(ssid) \(rssi)dB")
        }
        if let ssid = snap.ssid {
            return .text(ssid)
        }
        return .text("Wi-Fi —")
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
