import AppKit

/// Floating panel that hosts the currently active Mode's view. Owns
/// nothing about specific modes — it just swaps subviews on switchMode,
/// dispatches show/hide lifecycle, and reports size changes.
final class ModeHostWindow: NSPanel {
    override var canBecomeKey: Bool { true }

    private(set) var activeMode: Mode?
    private var previousApp: NSRunningApplication?
    private var container: NSView!

    var onSizeChanged: ((Double, Double) -> Void)?

    init(width: Double, height: Double) {
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = false
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 200, height: 100)

        centerOnScreen(width: width, height: height)

        let container = NSView(frame: rect)
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor
        contentView = container
        self.container = container

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification, object: self
        )
    }

    private func centerOnScreen(width: Double, height: Double) {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        setFrameOrigin(NSPoint(x: f.midX - width / 2, y: f.midY - height / 2))
    }

    func switchMode(_ mode: Mode) {
        if activeMode === mode { return }
        activeMode?.deactivate()

        for sub in container.subviews { sub.removeFromSuperview() }
        let v = mode.view()
        v.frame = container.bounds
        v.autoresizingMask = [.width, .height]
        container.addSubview(v)

        if let size = mode.preferredSize {
            var f = frame
            f.size = size
            setFrame(f, display: true, animate: false)
        }

        activeMode = mode
        mode.activate()
        focusActiveMode()
    }

    func show(mode: Mode) {
        previousApp = NSWorkspace.shared.frontmostApplication
        if activeMode !== mode {
            switchMode(mode)
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        activeMode?.windowDidShow()
        focusActiveMode()
    }

    func hide() {
        activeMode?.windowDidHide()
        orderOut(nil)
        if let app = previousApp {
            app.activate()
            previousApp = nil
        }
    }

    private func focusActiveMode() {
        guard let responder = activeMode?.preferredFirstResponder() else { return }
        makeFirstResponder(responder)
    }

    override func cancelOperation(_ sender: Any?) {
        hide()
    }

    override func close() {
        hide()
    }

    @objc private func windowDidResize(_ notification: Notification) {
        let size = frame.size
        onSizeChanged?(Double(size.width), Double(size.height))
    }
}
