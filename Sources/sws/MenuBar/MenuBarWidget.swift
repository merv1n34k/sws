import AppKit

/// A live-updating menu-bar item. Each widget owns one NSStatusItem
/// and a polling Timer; the registry creates/destroys these as the
/// user pins/unpins from the Status mode.
protocol MenuBarWidget: AnyObject {
    /// Stable id used to find/persist the widget (e.g. "cpu", "wifi").
    var id: String { get }
    /// Display label shown at the top of the detail popover.
    var detailTitle: String { get }
    /// How often to refresh in seconds. 0 = manual refresh only.
    var pollInterval: TimeInterval { get }
    /// Render the current value into a compact display payload
    /// (menu bar).
    func render() -> MenuBarRendering
    /// Plain-text value used by the Status dashboard buttons.
    /// Independent of `render()` so dashboards and menu-bar items
    /// can format differently.
    func currentValue() -> String
    /// Rich detail surface shown when the menu-bar button is clicked.
    /// Return nil to skip the popover entirely. Implementations should
    /// hold the view weakly or recreate it — the registry may call
    /// this once per popover open.
    func detailView() -> NSView?
}

extension MenuBarWidget {
    var detailTitle: String { id.capitalized }
    func currentValue() -> String { "" }
    func detailView() -> NSView? { nil }
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

    /// Compact left-aligned 2-line template image for the menu bar.
    /// Top line ≈ small label, bottom ≈ value. macOS tints it.
    ///
    /// `minWidth` reserves a stable rendering width so the widget
    /// doesn't jitter as the value changes (e.g. CPU 12% → 100%, or
    /// throughput 0 KB/s → 1.2 MB/s). Set it to the width of the
    /// worst-case top/bottom string at the same font.
    static func twoLines(top: String, bottom: String, minWidth: CGFloat = 0, tooltip: String? = nil) -> Self {
        let topFont = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let bottomFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

        // Template images use only the alpha channel; the actual color
        // is drawn as black on transparent and macOS recolors it.
        let topAttrs: [NSAttributedString.Key: Any] = [
            .font: topFont,
            .foregroundColor: NSColor.black,
        ]
        let bottomAttrs: [NSAttributedString.Key: Any] = [
            .font: bottomFont,
            .foregroundColor: NSColor.black,
        ]
        let topNS = top as NSString
        let bottomNS = bottom as NSString
        let topSize = topNS.size(withAttributes: topAttrs)
        let bottomSize = bottomNS.size(withAttributes: bottomAttrs)
        let measured = ceil(max(topSize.width, bottomSize.width)) + 4
        let width = max(measured, minWidth)
        let height: CGFloat = 22

        let img = NSImage(size: NSSize(width: width, height: height))
        img.lockFocus()
        // Left-aligned: both lines start at x=2.
        // y origin bottom-left; menu bar ~22pt: top baseline ≈ 12, bottom ≈ 1.
        topNS.draw(at: NSPoint(x: 2, y: 12), withAttributes: topAttrs)
        bottomNS.draw(at: NSPoint(x: 2, y: 1), withAttributes: bottomAttrs)
        img.unlockFocus()
        img.isTemplate = true
        return .init(text: nil, attributedText: nil, image: img, tooltip: tooltip)
    }
}
