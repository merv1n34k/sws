import AppKit

/// Always-on transparent overlay used while Color mode is active.
/// Click = single-pixel pick, drag = rectangular palette region.
/// The overlay sits BELOW the sws window in window level, so:
///   - clicks landing on the sws panel itself go to sws (copy buttons, etc.)
///   - clicks anywhere else hit the overlay
///   - on the first real drag movement we orderOut the sws window so it
///     doesn't block the user's view of what they're selecting; we bring
///     it back on mouseUp
///
/// The overlay stays alive across multiple picks — it's dismissed by
/// the host (ColorMode) when leaving color mode or hiding sws.
final class ColorPickerOverlay {
    enum Result {
        case single(NSColor)
        case region(CGImage)
        case cancelled
    }

    private var windows: [OverlayWindow] = []
    private weak var hostWindow: NSWindow?
    private var resultHandler: ((Result) -> Void)?

    func present(hostWindow: NSWindow, onResult: @escaping (Result) -> Void) {
        guard windows.isEmpty else { return }
        self.hostWindow = hostWindow
        self.resultHandler = onResult
        for screen in NSScreen.screens {
            let w = OverlayWindow(screen: screen, owner: self)
            w.orderFront(nil)
            windows.append(w)
        }
    }

    func dismiss() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        hostWindow = nil
        resultHandler = nil
    }

    // MARK: - Called by OverlayView

    func dragDidStart() {
        hostWindow?.orderOut(nil)
    }

    func finish(rectOnScreen rect: CGRect?, wasDrag: Bool) {
        defer {
            if wasDrag {
                hostWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        guard let rect = rect else {
            resultHandler?(.cancelled)
            return
        }
        if !wasDrag {
            let point = CGPoint(x: rect.midX, y: rect.midY)
            if let color = pickColor(at: point) {
                resultHandler?(.single(color))
            } else {
                resultHandler?(.cancelled)
            }
            return
        }
        if let img = captureScreenRegion(rect) {
            resultHandler?(.region(img))
        } else {
            resultHandler?(.cancelled)
        }
    }

    // MARK: - Capture

    /// Captures `rect` (in global CG screen coordinates) WITHOUT our
    /// own overlay windows. Uses the windowID filter rather than
    /// orderOut, because orderOut is asynchronous and the capture can
    /// race ahead of the window server actually removing the window.
    private func captureScreenRegion(_ rect: CGRect) -> CGImage? {
        // Pick any of our overlay windows as the z-order reference;
        // CGWindowListCreateImage with .optionOnScreenBelowWindow
        // returns all windows strictly below that one — our overlays
        // (same level, above) and the sws panel (.floating, above)
        // are both excluded automatically.
        if let any = windows.first {
            let id = CGWindowID(any.windowNumber)
            if let img = CGWindowListCreateImage(
                rect,
                .optionOnScreenBelowWindow,
                id,
                [.bestResolution, .boundsIgnoreFraming]
            ) {
                return img
            }
        }
        return CGWindowListCreateImage(rect, .optionAll, kCGNullWindowID, [.bestResolution])
    }

    private func pickColor(at point: CGPoint) -> NSColor? {
        let captureRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        guard let img = captureScreenRegion(captureRect) else {
            print("SWS picker: capture at (\(point.x), \(point.y)) returned nil")
            return nil
        }
        guard let rgb = PixelReader.firstPixel(of: img) else {
            print("SWS picker: pixel read failed (image \(img.width)x\(img.height))")
            return nil
        }
        let csName = (img.colorSpace?.name as String?) ?? "unknown"
        let alphaInfo = CGImageAlphaInfo(rawValue: img.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)!
        let little = img.bitmapInfo.contains(.byteOrder32Little)
        print("""
        SWS picker: cg(\(Int(point.x)),\(Int(point.y))) \
        image=\(img.width)x\(img.height) bpp=\(img.bitsPerPixel) row=\(img.bytesPerRow) \
        alpha=\(alphaInfo.rawValue) little=\(little) cs=\(csName) -> rgb(\(rgb.r),\(rgb.g),\(rgb.b))
        """)
        return NSColor(
            srgbRed: CGFloat(rgb.r) / 255,
            green: CGFloat(rgb.g) / 255,
            blue: CGFloat(rgb.b) / 255,
            alpha: 1
        )
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
        // Fully transparent — picker is meant to be ambient, not a tint.
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        // One level below .floating, so the sws panel (which IS .floating)
        // stays on top and its copy buttons remain clickable.
        self.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        self.setFrame(screen.frame, display: false)

        pickView.frame = NSRect(origin: .zero, size: screen.frame.size)
        pickView.autoresizingMask = [.width, .height]
        pickView.owner = owner
        pickView.screenOrigin = screen.frame.origin
        contentView = pickView
    }

    override var canBecomeKey: Bool { false }    // don't steal focus from sws
    override var canBecomeMain: Bool { false }
}

private final class OverlayView: NSView {
    weak var owner: ColorPickerOverlay?
    var screenOrigin: NSPoint = .zero

    private var startInView: NSPoint?
    private var currentInView: NSPoint?
    private var dragReported = false
    private let dragThreshold: CGFloat = 4

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startInView = convert(event.locationInWindow, from: nil)
        currentInView = startInView
        dragReported = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentInView = convert(event.locationInWindow, from: nil)
        if !dragReported, let start = startInView, let cur = currentInView {
            let d = hypot(cur.x - start.x, cur.y - start.y)
            if d > dragThreshold {
                dragReported = true
                owner?.dragDidStart()
            }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            startInView = nil
            currentInView = nil
            dragReported = false
            needsDisplay = true
        }
        guard let start = startInView, let end = currentInView else {
            owner?.finish(rectOnScreen: nil, wasDrag: false)
            return
        }
        owner?.finish(rectOnScreen: screenRect(from: start, to: end), wasDrag: dragReported)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let start = startInView, let end = currentInView, dragReported else { return }
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

    /// Convert two view-local points (AppKit bottom-left) into a CGRect
    /// in global CG coords (top-left origin, relative to primary screen).
    private func screenRect(from start: NSPoint, to end: NSPoint) -> CGRect {
        let s = NSPoint(x: start.x + screenOrigin.x, y: start.y + screenOrigin.y)
        let e = NSPoint(x: end.x + screenOrigin.x, y: end.y + screenOrigin.y)
        let minX = min(s.x, e.x)
        let minY = min(s.y, e.y)
        let w = abs(e.x - s.x)
        let h = abs(e.y - s.y)

        guard let primary = NSScreen.screens.first else {
            return CGRect(x: minX, y: minY, width: w, height: h)
        }
        let primaryHeight = primary.frame.height
        let cgY = primaryHeight - (minY + h)
        return CGRect(x: minX, y: cgY, width: w, height: h)
    }
}
