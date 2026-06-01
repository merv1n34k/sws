import AppKit

/// Floating panel that hosts the currently active Mode's view. Owns
/// nothing about specific modes — it just swaps subviews on switchMode,
/// dispatches show/hide lifecycle, and reports size changes.
final class ModeHostWindow: NSPanel {
    override var canBecomeKey: Bool { true }

    private(set) var activeMode: Mode?
    /// The app sws should return focus to on hide. Maintained
    /// continuously by `workspaceObserver` so even if the user
    /// switches apps WHILE sws is open, we restore to the most
    /// recently focused non-sws app (not the one that was frontmost
    /// when sws was originally summoned).
    private var previousApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?
    private var container: NSView!
    private var dragMonitor: Any?
    private var dragOrigin: NSPoint?

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
        // Mode views all use a dark backdrop. Force dark appearance
        // so system controls (segmented, popup, checkbox text) render
        // with light text and contrast against it correctly.
        self.appearance = NSAppearance(named: .darkAqua)

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

        installWorkspaceObserver()
        installOptionDragMonitor()
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// ⌥+drag moves the window from anywhere inside its content. Works
    /// for every hosted mode — the legacy per-mode handler in
    /// TerminalView is removed. Only consumes the event while the
    /// gesture is active so normal clicks still reach the mode's view.
    private func installOptionDragMonitor() {
        dragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            guard let self = self, event.window === self else { return event }
            switch event.type {
            case .leftMouseDown:
                if event.modifierFlags.contains(.option) {
                    self.dragOrigin = event.locationInWindow
                    return nil
                }
            case .leftMouseDragged:
                if let origin = self.dragOrigin {
                    let current = event.locationInWindow
                    var f = self.frame
                    f.origin.x += current.x - origin.x
                    f.origin.y += current.y - origin.y
                    self.setFrameOrigin(f.origin)
                    return nil
                }
            case .leftMouseUp:
                if self.dragOrigin != nil {
                    self.dragOrigin = nil
                    return nil
                }
            default:
                break
            }
            return event
        }
    }

    /// Seeds `previousApp` and subscribes to NSWorkspace activation
    /// notifications so previousApp tracks the most recently focused
    /// non-sws application at all times.
    private func installWorkspaceObserver() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.previousApp = app
        }
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

        applyWindowSizing(for: mode)

        activeMode = mode
        mode.activate()
        focusActiveMode()
    }

    /// Honor the mode's preferredSize + fixedSize. If fixedSize the
    /// window is locked (resizable handle disabled, min/max equal);
    /// otherwise the window can be freely resized within sensible
    /// bounds.
    private func applyWindowSizing(for mode: Mode) {
        let floor = mode.minSize ?? NSSize(width: 200, height: 100)
        guard let size = mode.preferredSize else {
            minSize = floor
            maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            if !styleMask.contains(.resizable) { styleMask.insert(.resizable) }
            return
        }
        if mode.fixedSize {
            minSize = size
            maxSize = size
            styleMask.remove(.resizable)
        } else {
            minSize = floor
            maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            if !styleMask.contains(.resizable) { styleMask.insert(.resizable) }
        }
        var f = frame
        f.size = NSSize(
            width: max(size.width, floor.width),
            height: max(size.height, floor.height)
        )
        setFrame(f, display: true, animate: false)
    }

    func show(mode: Mode) {
        // previousApp is maintained by the workspace observer; no need
        // to snapshot it here.
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
        if let app = previousApp, !app.isTerminated {
            app.activate()
        }
        // Keep previousApp populated — the observer will overwrite it
        // when the user next focuses a different non-sws app.
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
