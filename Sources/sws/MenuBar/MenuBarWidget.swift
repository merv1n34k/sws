import AppKit

/// A live-updating menu-bar item. Each widget owns one NSStatusItem
/// and a polling Timer; the registry creates/destroys these as the
/// user pins/unpins from the Status mode.
protocol MenuBarWidget: AnyObject {
    /// Stable id used to find/persist the widget (e.g. "cpu", "wifi").
    var id: String { get }
    /// How often to refresh in seconds. 0 = manual refresh only.
    var pollInterval: TimeInterval { get }
    /// Render the current value into a compact display payload.
    func render() -> MenuBarRendering
}

/// What gets shown on the menu-bar button.
struct MenuBarRendering {
    var text: String? = nil
    var attributedText: NSAttributedString? = nil
    var image: NSImage? = nil
    /// Optional tooltip with longer context.
    var tooltip: String? = nil
}

extension MenuBarRendering {
    static func text(_ s: String, tooltip: String? = nil) -> Self {
        .init(text: s, attributedText: nil, image: nil, tooltip: tooltip)
    }
    static func attributed(_ a: NSAttributedString, tooltip: String? = nil) -> Self {
        .init(text: nil, attributedText: a, image: nil, tooltip: tooltip)
    }
    static func image(_ img: NSImage, tooltip: String? = nil) -> Self {
        .init(text: nil, attributedText: nil, image: img, tooltip: tooltip)
    }
}
