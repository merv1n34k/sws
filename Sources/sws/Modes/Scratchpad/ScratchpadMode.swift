import AppKit

final class ScratchpadMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 520, height: 360)

    private lazy var rootView = ScratchpadView()

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func view() -> NSView { rootView }

    func preferredFirstResponder() -> NSResponder? {
        rootView.textView
    }
}

enum ScratchpadModeFactory: ModeFactory {
    static let typeId = "scratchpad"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? "Scratchpad"
        return ScratchpadMode(id: instance.id, displayName: name)
    }
}
