import AppKit

final class TerminalWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    let terminalView: TerminalView
    private var config: SWSConfig
    private var previousApp: NSRunningApplication?
    var onSizeChanged: ((Double, Double) -> Void)?

    init(config: SWSConfig) {
        self.config = config
        self.terminalView = TerminalView(config: config)

        let rect = NSRect(x: 0, y: 0, width: config.width, height: config.height)
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

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - config.width / 2
            let y = screenFrame.midY - config.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Rounded container with border
        let container = NSView(frame: rect)
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        contentView = container
        terminalView.frame = container.bounds
        terminalView.autoresizingMask = [.width, .height]
        container.addSubview(terminalView)

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification, object: self
        )
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        if !terminalView.isProcessRunning {
            terminalView.startProcess()
        }
        terminalView.writeSessionSeparator()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        makeFirstResponder(terminalView.terminal)
    }

    func hide() {
        orderOut(nil)
        if let app = previousApp {
            app.activate()
            previousApp = nil
        }
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func reloadConfig(_ newConfig: SWSConfig) {
        config = newConfig
        terminalView.updateConfig(newConfig)
    }

    override func cancelOperation(_ sender: Any?) {
        hide()
    }

    override func close() {
        // Hide instead of close
        hide()
    }

    @objc private func windowDidResize(_ notification: Notification) {
        let size = frame.size
        onSizeChanged?(Double(size.width), Double(size.height))
    }
}
