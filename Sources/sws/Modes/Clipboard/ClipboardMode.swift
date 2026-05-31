import AppKit

final class ClipboardMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 520, height: 420)

    private lazy var rootView = ClipboardView()

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
        // Start the monitor as soon as we're constructed — even when
        // the user hasn't opened the mode yet, we want to be capturing.
        ClipboardMonitor.shared.start()
    }

    func view() -> NSView { rootView }

    func windowDidShow() { rootView.refresh() }
}

enum ClipboardModeFactory: ModeFactory {
    static let typeId = "clipboard"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? "Clipboard"
        return ClipboardMode(id: instance.id, displayName: name)
    }
}
