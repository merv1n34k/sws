import AppKit

/// Loupe-style magnifier shown next to the cursor while the picker
/// overlay is active. Captures a small region of the screen at the
/// cursor, displays it zoomed, and highlights the center pixel —
/// the one that would be picked by a click right now.
final class MagnifierView: NSView {
    /// Side of the captured region in points (pre-zoom).
    var captureSize: CGFloat = 11
    /// Magnification factor applied when drawing.
    var zoom: CGFloat = 10

    private var lastImage: CGImage?
    private var lastHex: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Update the magnifier with a fresh capture centered on `screenPoint`
    /// (CG screen coords, top-left origin).
    func update(centerScreenPoint p: CGPoint, capture: (CGRect) -> CGImage?) {
        let rect = CGRect(
            x: p.x - captureSize / 2,
            y: p.y - captureSize / 2,
            width: captureSize,
            height: captureSize
        )
        lastImage = capture(rect)
        if let img = lastImage,
           let mid = PixelReader.pixel(of: img, atX: img.width / 2, y: img.height / 2) {
            lastHex = String(format: "#%02X%02X%02X", mid.r, mid.g, mid.b)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let img = lastImage, let ctx = NSGraphicsContext.current?.cgContext else { return }

        let zoomedRect = NSRect(x: 0, y: 22, width: bounds.width, height: bounds.height - 22)

        ctx.saveGState()
        ctx.interpolationQuality = .none  // pixelated look = crisper at high zoom
        ctx.draw(img, in: zoomedRect)
        ctx.restoreGState()

        // Crosshair on the center pixel
        let cx = zoomedRect.midX
        let cy = zoomedRect.midY
        let pixelInZoomed = zoomedRect.width / CGFloat(img.width)
        let cellRect = NSRect(
            x: cx - pixelInZoomed / 2,
            y: cy - pixelInZoomed / 2,
            width: pixelInZoomed,
            height: pixelInZoomed
        )
        NSColor.white.setStroke()
        let cell = NSBezierPath(rect: cellRect)
        cell.lineWidth = 1.5
        cell.stroke()
        NSColor.black.setStroke()
        let outer = NSBezierPath(rect: cellRect.insetBy(dx: -1, dy: -1))
        outer.lineWidth = 1
        outer.stroke()

        // Hex readout strip at the bottom
        let stripRect = NSRect(x: 0, y: 0, width: bounds.width, height: 22)
        NSColor(white: 0.1, alpha: 0.9).setFill()
        stripRect.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let text = lastHex as NSString
        let size = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (22 - size.height) / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: textRect, withAttributes: attrs)
    }
}
