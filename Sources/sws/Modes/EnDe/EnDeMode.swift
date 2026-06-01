import AppKit

final class EnDeMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 720, height: 440)
    /// Without a floor the user can resize the window narrow enough to
    /// hide the input pane entirely.
    let minSize: NSSize? = NSSize(width: 560, height: 320)

    private lazy var rootView = TwoPaneConverter(codecs: [
        Base64Codec(),
        URLCodec(),
        CSVMarkdownCodec(),
        JWTCodec(),
        QRCodec(),
        BarcodeCodec(),
    ])

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func view() -> NSView { rootView }
}

enum EnDeModeFactory: ModeFactory {
    static let typeId = "ende"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? "EnDe"
        return EnDeMode(id: instance.id, displayName: name)
    }
}
