import AppKit

final class ColorMode: Mode {
    let id: String
    let displayName: String
    var preferredSize: NSSize? = NSSize(width: 380, height: 360)

    private(set) var current: NSColor?
    private(set) var palette: [NSColor] = []
    private(set) var history: [NSColor] = []
    private let historyLimit = 8

    private lazy var rootView = ColorView(mode: self)

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func view() -> NSView { rootView }

    func activate() { rootView.refresh() }

    func windowDidShow() { rootView.refresh() }

    func apply(color: NSColor) {
        current = color
        palette = []   // a single pick clears the palette
        recordInHistory(color)
        rootView.refresh()
    }

    func apply(palette: [NSColor]) {
        self.palette = palette
        current = palette.first
        if let first = palette.first {
            recordInHistory(first)
        }
        rootView.refresh()
    }

    private func recordInHistory(_ color: NSColor) {
        if let existing = history.firstIndex(where: { ColorFormat.hex($0) == ColorFormat.hex(color) }) {
            history.remove(at: existing)
        }
        history.insert(color, at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
    }

    /// CSV of the active palette (or the single current color if no
    /// palette is active). Used by the "click palette to copy" gesture.
    func paletteCSV() -> String {
        let colors = palette.isEmpty ? (current.map { [$0] } ?? []) : palette
        return colors.map { ColorFormat.hex($0) }.joined(separator: ",")
    }
}

enum ColorModeFactory: ModeFactory {
    static let typeId = "color"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let displayName = (instance.raw["displayName"] as? String) ?? instance.id.capitalized
        return ColorMode(id: instance.id, displayName: displayName)
    }
}

// MARK: - Color formatting

enum ColorFormat {
    /// Hex like "#A1B2C3".
    static func hex(_ color: NSColor) -> String {
        let c = srgb(color)
        let r = Int(round(c.r * 255))
        let g = Int(round(c.g * 255))
        let b = Int(round(c.b * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// "rgb(161, 178, 195)".
    static func rgb(_ color: NSColor) -> String {
        let c = srgb(color)
        let r = Int(round(c.r * 255))
        let g = Int(round(c.g * 255))
        let b = Int(round(c.b * 255))
        return "rgb(\(r), \(g), \(b))"
    }

    /// "hsl(217, 24%, 70%)".
    static func hsl(_ color: NSColor) -> String {
        let c = srgb(color)
        let (h, s, l) = hslComponents(r: c.r, g: c.g, b: c.b)
        return String(format: "hsl(%d, %d%%, %d%%)",
            Int(round(h * 360)),
            Int(round(s * 100)),
            Int(round(l * 100)))
    }

    /// "hsb(217, 18%, 76%)".
    static func hsb(_ color: NSColor) -> String {
        let c = srgb(color)
        let (h, s, b) = hsbComponents(r: c.r, g: c.g, b: c.b)
        return String(format: "hsb(%d, %d%%, %d%%)",
            Int(round(h * 360)),
            Int(round(s * 100)),
            Int(round(b * 100)))
    }

    private static func srgb(_ color: NSColor) -> (r: Double, g: Double, b: Double) {
        let c = color.usingColorSpace(.sRGB) ?? color
        return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }

    /// Returns components in [0, 1].
    static func hslComponents(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let mx = max(r, g, b)
        let mn = min(r, g, b)
        let l = (mx + mn) / 2
        if mx == mn { return (0, 0, l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        switch mx {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h /= 6
        return (h, s, l)
    }

    /// Returns components in [0, 1].
    static func hsbComponents(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let mx = max(r, g, b)
        let mn = min(r, g, b)
        let v = mx
        if mx == 0 { return (0, 0, 0) }
        let s = (mx - mn) / mx
        if mx == mn { return (0, 0, v) }
        let d = mx - mn
        var h: Double
        switch mx {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h /= 6
        return (h, s, v)
    }
}
