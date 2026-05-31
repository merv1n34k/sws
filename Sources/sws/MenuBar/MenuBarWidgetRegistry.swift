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
            NSStatusBar.system.removeStatusItem(item)
        }
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

    private func renderInto(item: NSStatusItem, widget: MenuBarWidget) {
        let r = widget.render()
        if let btn = item.button {
            btn.title = r.text ?? ""
            btn.image = r.image
            btn.toolTip = r.tooltip
            btn.imagePosition = (r.image != nil && r.text != nil) ? .imageLeading : .imageOnly
            if r.image == nil { btn.imagePosition = .noImage }
        }
    }

    private func persist() {
        store.save(PinnedState(pinnedIds: Array(pinnedIds).sorted()))
    }
}
