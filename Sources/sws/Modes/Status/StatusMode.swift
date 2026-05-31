import AppKit

final class StatusMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 460, height: 460)
    let fixedSize: Bool = true

    private lazy var rootView = StatusView()

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
        // Register status widgets so the registry can spawn them on
        // pin / restore from prior session.
        for kind in StatusWidgetID.allCases {
            MenuBarWidgetRegistry.shared.registerWidget(id: kind.rawValue) {
                kind.makeWidget()
            }
        }
        MenuBarWidgetRegistry.shared.restorePinned()
    }

    func view() -> NSView { rootView }
    func windowDidShow() { rootView.refresh() }
}

enum StatusModeFactory: ModeFactory {
    static let typeId = "status"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? "Status"
        return StatusMode(id: instance.id, displayName: name)
    }
}
