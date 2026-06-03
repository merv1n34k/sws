import AppKit

/// Borderless floating window used in place of `NSPopover` for widget
/// detail surfaces. NSPopover's arrow always points at the anchoring
/// view and can't be hidden through public API, so we render a plain
/// rounded panel below the status item using NSVisualEffectView for
/// the macOS-native menu material.
final class WidgetPopup {
    private var window: NSWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var isShown: Bool { window?.isVisible == true }

    func show(content: NSView, anchoredTo button: NSStatusBarButton) {
        close()

        content.translatesAutoresizingMaskIntoConstraints = false

        let visual = NSVisualEffectView()
        visual.material = .menu
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 10
        visual.layer?.masksToBounds = true
        visual.translatesAutoresizingMaskIntoConstraints = false
        visual.addSubview(content)

        // Padding around the popover body. Match the inset rhythm of
        // standard macOS menu panels.
        let pad: CGFloat = 0  // body already has its own insets
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: visual.topAnchor, constant: pad),
            content.bottomAnchor.constraint(equalTo: visual.bottomAnchor, constant: -pad),
            content.leadingAnchor.constraint(equalTo: visual.leadingAnchor, constant: pad),
            content.trailingAnchor.constraint(equalTo: visual.trailingAnchor, constant: -pad),
        ])

        let fitting = content.fittingSize
        let size = NSSize(
            width: max(280, fitting.width),
            height: max(80, fitting.height)
        )

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .popUpMenu
        w.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        w.isMovableByWindowBackground = false
        w.contentView = visual

        // Position the panel just below the status item button on the
        // same screen. Right-anchor when the button is too close to the
        // screen's right edge so the panel doesn't clip off-screen.
        guard let buttonWindow = button.window else { return }
        let buttonScreenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main!
        let screenFrame = screen.frame
        let gap: CGFloat = 6
        var originX = buttonScreenRect.midX - size.width / 2
        originX = max(screenFrame.minX + 6, min(screenFrame.maxX - size.width - 6, originX))
        let originY = buttonScreenRect.minY - size.height - gap
        w.setFrameOrigin(NSPoint(x: originX, y: originY))

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w

        installDismissalMonitors()
    }

    func close() {
        removeDismissalMonitors()
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Dismissal

    private func installDismissalMonitors() {
        // Click outside (other apps) → close.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
        // Click inside sws but outside our popup → close. Clicks inside
        // the popup pass through normally so the user can interact with
        // it (Refresh button, etc.).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.window {
                self?.close()
            }
            return event
        }
    }

    private func removeDismissalMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }
}
