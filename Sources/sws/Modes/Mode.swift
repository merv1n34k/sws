import AppKit

/// A mode is a distinct piece of UI hosted by the floating window.
/// Modes live for the app's lifetime so background work (timers,
/// PTYs) keeps running across mode switches and window hides.
protocol Mode: AnyObject {
    var id: String { get }
    var displayName: String { get }
    /// If non-nil, the host window resizes to this on activate.
    var preferredSize: NSSize? { get }

    /// Returns the mode's view. Implementations cache; callers may
    /// invoke this on every activate.
    func view() -> NSView

    /// Called when this mode becomes the active mode in the window.
    func activate()
    /// Called when another mode is taking over. NOT called on window hide.
    func deactivate()
    /// Window became visible (this mode is the active one).
    func windowDidShow()
    /// Window hid (this mode is the active one). The mode may continue
    /// background work; it just won't be visible.
    func windowDidHide()

    /// Returns the responder that should receive keystrokes when the
    /// mode is active. Default: the mode's view.
    func preferredFirstResponder() -> NSResponder?

    /// When true, the host window is locked to `preferredSize` (no
    /// resize handle, no min/max breathing). Useful for dashboards
    /// or other modes whose grid layout doesn't benefit from
    /// resizing.
    var fixedSize: Bool { get }
}

extension Mode {
    var preferredSize: NSSize? { nil }
    func activate() {}
    func deactivate() {}
    func windowDidShow() {}
    func windowDidHide() {}
    func preferredFirstResponder() -> NSResponder? { view() }
    var fixedSize: Bool { false }
}

/// Per-mode-instance config slice handed to a factory.
struct ModeInstanceConfig {
    let id: String
    let typeId: String
    let hotkey: ShortcutConfig?
    /// Remaining JSON fields not consumed by the core (command, args,
    /// worldClocks, …) keyed by JSON key.
    let raw: [String: Any]
}

/// App-wide preferences shared across modes (font, logging) so each
/// factory doesn't reach into a global.
struct AppPrefs {
    var fontFamily: String
    var fontSize: Double
    var logInput: Bool
}

/// A factory builds Mode instances from config.
protocol ModeFactory {
    static var typeId: String { get }
    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode
}

enum ModeError: Error, CustomStringConvertible {
    case unknownType(String)
    case missingField(String)
    case invalidField(String, reason: String)

    var description: String {
        switch self {
        case .unknownType(let t): return "unknown mode type '\(t)'"
        case .missingField(let f): return "missing field '\(f)'"
        case .invalidField(let f, let r): return "invalid field '\(f)': \(r)"
        }
    }
}

/// Central registry of mode factories. The core never references
/// specific mode types — it asks the registry by typeId.
final class ModeRegistry {
    static let shared = ModeRegistry()
    private var factories: [String: ModeFactory.Type] = [:]
    private var aliases: [String: String] = [:]

    func register(_ factory: ModeFactory.Type) {
        factories[factory.typeId] = factory
    }

    /// Maps a legacy/alternate typeId to a canonical one. Used to keep
    /// old configs working after a mode is renamed.
    func registerAlias(_ alias: String, to canonical: String) {
        aliases[alias] = canonical
    }

    func make(_ instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let resolved = aliases[instance.typeId] ?? instance.typeId
        guard let factory = factories[resolved] else {
            throw ModeError.unknownType(instance.typeId)
        }
        return try factory.make(instance: instance, appPrefs: appPrefs)
    }

    func has(typeId: String) -> Bool {
        let resolved = aliases[typeId] ?? typeId
        return factories[resolved] != nil
    }
}
