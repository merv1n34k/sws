import AppKit

/// Borderless floating window used in place of `NSPopover` for widget
/// detail surfaces. NSPopover's arrow always points at the anchoring
/// view and can't be hidden through public API, so we render a plain
/// rounded panel below the status item using NSVisualEffectView for
/// the macOS-native menu material.
final class WidgetPopup {
    private var window: NSWindow?
    private weak var anchorWindow: NSWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var isShown: Bool { window?.isVisible == true }

    func show(content: NSView, anchoredTo button: NSStatusBarButton) {
        close()

        content.translatesAutoresizingMaskIntoConstraints = false

        let cornerRadius: CGFloat = 10
        let visual = NSVisualEffectView()
        visual.material = .menu
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.wantsLayer = true
        visual.layer?.cornerRadius = cornerRadius
        visual.layer?.cornerCurve = .continuous
        visual.layer?.masksToBounds = true
        // NSWindow's shadow is rectangular by default. Setting
        // `maskImage` to a 9-slice rounded-rect bitmap makes the shadow
        // follow the same rounded shape as the contentView, so the
        // popover renders without the sharp-corner shadow overlay.
        visual.maskImage = Self.makeMaskImage(cornerRadius: cornerRadius)
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
        anchorWindow = buttonWindow

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
        // Click inside sws but outside our popup → close. Two carve-outs:
        // - Clicks inside the popup itself pass through (user can hit
        //   the Refresh / Unpin buttons).
        // - Clicks on the same anchor status item are NOT closed here;
        //   instead they're forwarded to the button action which then
        //   toggles the popup off. Closing here would race with the
        //   button action, which sees the popup as already closed and
        //   reopens it.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if event.window === self.window { return event }
            if event.window === self.anchorWindow { return event }
            self.close()
            return event
        }
    }

    private func removeDismissalMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    /// 9-slice rounded-rect mask. NSWindow uses the mask's alpha to
    /// shape its shadow, which is why we need this instead of just
    /// setting `layer.cornerRadius`.
    private static func makeMaskImage(cornerRadius: CGFloat) -> NSImage {
        let edge = cornerRadius * 2 + 1
        let img = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.setFill()
            path.fill()
            return true
        }
        img.capInsets = NSEdgeInsets(
            top: cornerRadius, left: cornerRadius,
            bottom: cornerRadius, right: cornerRadius
        )
        img.resizingMode = .stretch
        return img
    }
}
