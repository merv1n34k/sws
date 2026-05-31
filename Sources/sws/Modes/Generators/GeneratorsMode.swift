import AppKit

/// Mode wrapper exposing the Generators view to the registry.
final class GeneratorsMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 460, height: 360)

    private lazy var rootView = GeneratorsView()

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func view() -> NSView { rootView }
}

enum GeneratorsModeFactory: ModeFactory {
    static let typeId = "generators"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? instance.id.capitalized
        return GeneratorsMode(id: instance.id, displayName: name)
    }
}
