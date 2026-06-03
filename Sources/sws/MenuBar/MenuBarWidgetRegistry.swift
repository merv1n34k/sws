import AppKit

/// Owns the set of active menu-bar widgets and the NSStatusItem for
/// each. Persists the pinned-id set to ~/.config/sws/menubar.json so
/// pins survive relaunch.
final class MenuBarWidgetRegistry {
    static let shared = MenuBarWidgetRegistry()

    private struct PinnedState: Codable {
        var pinnedIds: [String] = []
    }

    private let store = PersistentStore<PinnedState>(key: "menubar.json")
    private var available: [String: () -> MenuBarWidget] = [:]
    private var activeWidgets: [String: MenuBarWidget] = [:]
    private var statusItems: [String: NSStatusItem] = [:]
    private var timers: [String: Timer] = [:]
    private var pinnedIds: Set<String> = []
    private var popovers: [String: WidgetPopup] = [:]
    /// Maps a status-item button's hash to its widget id so the click
    /// handler can find the right popover.
    private var buttonToId: [ObjectIdentifier: String] = [:]

    /// Subscribe-once notification fired when any widget is
    /// added/removed; views like StatusView listen to refresh button
    /// states without polling the registry.
    static let didChangeNotification = Notification.Name("sws.menubar.didChange")

    private init() {
        let state = store.load(PinnedState())
        self.pinnedIds = Set(state.pinnedIds)
    }

    /// Register a widget factory. Idempotent.
    func registerWidget(id: String, factory: @escaping () -> MenuBarWidget) {
        available[id] = factory
    }

    /// Activates every widget that was pinned before. Call once from
    /// AppDelegate after registering widgets at launch.
    func restorePinned() {
        for id in pinnedIds where activeWidgets[id] == nil {
            spawn(id: id)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func isPinned(id: String) -> Bool {
        pinnedIds.contains(id)
    }

    /// Toggle a widget on/off. Caller is responsible for ensuring
    /// `registerWidget` was called for `id` first.
    func togglePinned(id: String) {
        if pinnedIds.contains(id) {
            unpin(id: id)
        } else {
            pin(id: id)
        }
    }

    func pin(id: String) {
        guard !pinnedIds.contains(id) else { return }
        guard available[id] != nil else {
            NSLog("SWS menubar: pin(\(id)) but no widget registered")
            return
        }
        pinnedIds.insert(id)
        spawn(id: id)
        persist()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func unpin(id: String) {
        guard pinnedIds.contains(id) else { return }
        pinnedIds.remove(id)
        timers.removeValue(forKey: id)?.invalidate()
        if let item = statusItems.removeValue(forKey: id) {
            if let btn = item.button {
                buttonToId.removeValue(forKey: ObjectIdentifier(btn))
            }
            NSStatusBar.system.removeStatusItem(item)
        }
        popovers.removeValue(forKey: id)?.close()
        activeWidgets.removeValue(forKey: id)
        persist()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    // MARK: - Internal

    private func spawn(id: String) {
        guard let factory = available[id] else { return }
        let widget = factory()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        activeWidgets[id] = widget
        statusItems[id] = item
        if let btn = item.button {
            btn.target = self
            btn.action = #selector(statusButtonClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
            buttonToId[ObjectIdentifier(btn)] = id
        }
        renderInto(item: item, widget: widget)
        if widget.pollInterval > 0 {
            let t = Timer(timeInterval: widget.pollInterval, repeats: true) { [weak self] _ in
                guard let self = self,
                      let item = self.statusItems[id],
                      let widget = self.activeWidgets[id] else { return }
                self.renderInto(item: item, widget: widget)
            }
            RunLoop.main.add(t, forMode: .common)
            timers[id] = t
        }
    }

    // MARK: - Popover

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let id = buttonToId[ObjectIdentifier(sender)],
              let widget = activeWidgets[id] else { return }

        // Right-click → contextual menu with Unpin. Left-click → popover.
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            let item = NSMenuItem(title: "Unpin \(widget.detailTitle)", action: #selector(unpinFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            menu.addItem(item)
            statusItems[id]?.menu = menu
            sender.performClick(nil)
            // Clear so the next left-click reopens the popover rather
            // than re-showing the menu.
            DispatchQueue.main.async { [weak self] in self?.statusItems[id]?.menu = nil }
            return
        }

        togglePopover(for: id, widget: widget, anchor: sender)
    }

    @objc private func unpinFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        unpin(id: id)
    }

    private func togglePopover(for id: String, widget: MenuBarWidget, anchor: NSView) {
        if let existing = popovers[id], existing.isShown {
            existing.close()
            return
        }
        guard let body = widget.detailView() else { return }
        let wrapper = WidgetPopover.wrap(title: widget.detailTitle, body: body) { [weak self] in
            self?.popovers[id]?.close()
            self?.unpin(id: id)
        }

        guard let btn = anchor as? NSStatusBarButton else { return }
        let pop = WidgetPopup()
        pop.show(content: wrapper, anchoredTo: btn)
        popovers[id] = pop
    }

    private func renderInto(item: NSStatusItem, widget: MenuBarWidget) {
        let r = widget.render()
        guard let btn = item.button else { return }
        if let attr = r.attributedText {
            btn.attributedTitle = attr
            btn.title = ""
        } else {
            btn.title = r.text ?? ""
            btn.attributedTitle = NSAttributedString(string: r.text ?? "")
        }
        btn.image = r.image
        btn.toolTip = r.tooltip
        // Force image flush to the leading edge. `.imageOnly` centers
        // the image inside the button regardless of `alignment`. Using
        // `.imageLeading` with an empty title pushes the image to the
        // left edge and respects `alignment = .left`.
        if r.image != nil {
            btn.imagePosition = .imageLeading
        } else {
            btn.imagePosition = .noImage
        }
        btn.alignment = .left
        btn.imageScaling = .scaleNone
        // Match status-item slot width to the image so there's no extra
        // gutter the system might center against.
        if let img = r.image {
            item.length = img.size.width + 4
        }
    }

    private func persist() {
        store.save(PinnedState(pinnedIds: Array(pinnedIds).sorted()))
    }
}
