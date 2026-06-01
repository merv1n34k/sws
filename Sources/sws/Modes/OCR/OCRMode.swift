import AppKit

final class OCRMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 600, height: 480)

    private lazy var rootView = OCRView()

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func view() -> NSView { rootView }

    func windowDidShow() {
        rootView.autoLoadFromPasteboardIfAvailable()
    }
}

enum OCRModeFactory: ModeFactory {
    static let typeId = "ocr"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? "OCR"
        return OCRMode(id: instance.id, displayName: name)
    }
}
