import AppKit

/// Fullscreen transparent window that captures a single mouse gesture:
/// click = single pixel pick, drag = rectangular region pick.
/// Replaces NSColorSampler so we can support drag-to-palette.
final class ColorPickerOverlay {
    enum Result {
        case single(NSColor)
        case region(CGImage)
        case cancelled
    }

    private var windows: [NSWindow] = []
    private var captureHandler: ((Result) -> Void)?
    private static var active: ColorPickerOverlay?

    func present(completion: @escaping (Result) -> Void) {
        captureHandler = completion
        ColorPickerOverlay.active = self
        for screen in NSScreen.screens {
            let w = OverlayWindow(screen: screen, owner: self)
            w.orderFrontRegardless()
            windows.append(w)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func finish(rectOnScreen rect: CGRect?) {
        let dragThreshold: CGFloat = 4
        defer { dismiss() }

        guard let rect = rect else {
            captureHandler?(.cancelled)
            return
        }

        if rect.width < dragThreshold && rect.height < dragThreshold {
            // Treat as single pixel pick at the click point
            let point = CGPoint(x: rect.midX, y: rect.midY)
            if let color = pickColor(at: point) {
                captureHandler?(.single(color))
            } else {
                captureHandler?(.cancelled)
            }
            return
        }

        if let img = captureScreenRegion(rect) {
            captureHandler?(.region(img))
        } else {
            captureHandler?(.cancelled)
        }
    }

    private func dismiss() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        captureHandler = nil
        if ColorPickerOverlay.active === self { ColorPickerOverlay.active = nil }
    }

    // MARK: - Screen capture

    /// `rect` is in screen coordinates with origin at top-left of the
    /// primary display (CGRect convention used by Core Graphics).
    private func captureScreenRegion(_ rect: CGRect) -> CGImage? {
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.bestResolution]
        )
    }

    private func pickColor(at point: CGPoint) -> NSColor? {
        let captureRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        guard let img = captureScreenRegion(captureRect),
              let data = img.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        // CGImage may have arbitrary bytes per row; we asked for 1x1
        // so the first pixel is at offset 0. Pixel format from
        // CGWindowListCreateImage on macOS: BGRA (premultiplied first).
        let info = img.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: info.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
        let isBGRA = info.contains(.byteOrder32Little)
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        if isBGRA {
            b = CGFloat(bytes[0]) / 255
            g = CGFloat(bytes[1]) / 255
            r = CGFloat(bytes[2]) / 255
        } else {
            r = CGFloat(bytes[0]) / 255
            g = CGFloat(bytes[1]) / 255
            b = CGFloat(bytes[2]) / 255
        }
        _ = alphaInfo
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Overlay window

private final class OverlayWindow: NSPanel {
    private weak var owner: ColorPickerOverlay?
    private let pickView: OverlayView

    init(screen: NSScreen, owner: ColorPickerOverlay) {
        self.owner = owner
        self.pickView = OverlayView()
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.05)
        self.isOpaque = false
        self.hasShadow = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.setFrame(screen.frame, display: false)

        pickView.frame = NSRect(origin: .zero, size: screen.frame.size)
        pickView.autoresizingMask = [.width, .height]
        pickView.owner = owner
        pickView.screenOrigin = screen.frame.origin
        contentView = pickView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        owner?.finish(rectOnScreen: nil)
    }

    override func keyDown(with event: NSEvent) {
        // Escape — already handled via cancelOperation in some configs;
        // be defensive.
        if event.keyCode == 53 { // kVK_Escape
            owner?.finish(rectOnScreen: nil)
            return
        }
        super.keyDown(with: event)
    }
}

private final class OverlayView: NSView {
    weak var owner: ColorPickerOverlay?
    /// Origin of the screen this view covers, in global screen coords
    /// (top-left convention via NSScreen.frame.origin in AppKit, which
    /// is BOTTOM-left — we convert).
    var screenOrigin: NSPoint = .zero

    private var startInView: NSPoint?
    private var currentInView: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startInView = convert(event.locationInWindow, from: nil)
        currentInView = startInView
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentInView = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = startInView, let end = currentInView else {
            owner?.finish(rectOnScreen: nil)
            return
        }
        owner?.finish(rectOnScreen: screenRect(from: start, to: end))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let start = startInView, let end = currentInView else { return }
        let rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        NSColor(white: 1, alpha: 0.1).setFill()
        rect.fill()

        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1.5
        path.stroke()
    }

    /// Convert two view-local points (AppKit bottom-left coords) into a
    /// CGRect in Core Graphics screen coordinates (top-left origin),
    /// which is what CGWindowListCreateImage expects.
    private func screenRect(from start: NSPoint, to end: NSPoint) -> CGRect {
        // Compose into AppKit screen coordinates by adding the window's
        // screen origin.
        let s = NSPoint(x: start.x + screenOrigin.x, y: start.y + screenOrigin.y)
        let e = NSPoint(x: end.x + screenOrigin.x, y: end.y + screenOrigin.y)
        let minX = min(s.x, e.x)
        let minY = min(s.y, e.y)
        let w = abs(e.x - s.x)
        let h = abs(e.y - s.y)

        // Flip y: NSScreen uses bottom-left, CG uses top-left, relative
        // to the *primary* screen height.
        guard let primary = NSScreen.screens.first else {
            return CGRect(x: minX, y: minY, width: w, height: h)
        }
        let primaryHeight = primary.frame.height
        let cgY = primaryHeight - (minY + h)
        return CGRect(x: minX, y: cgY, width: w, height: h)
    }
}
