import AppKit

/// Wraps a TerminalView in the Mode protocol so the host window can
/// treat it like any other mode. One TerminalMode = one configured
/// command (e.g. bc, python3); multiple TerminalMode instances coexist
/// independently.
final class TerminalMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = nil

    private var viewConfig: TerminalViewConfig
    private lazy var terminalView: TerminalView = {
        let view = TerminalView(config: viewConfig)
        view.onProcessExit = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.terminalView.startProcess()
            }
        }
        return view
    }()

    init(id: String, displayName: String, viewConfig: TerminalViewConfig) {
        self.id = id
        self.displayName = displayName
        self.viewConfig = viewConfig
    }

    func view() -> NSView { terminalView }

    func activate() {
        if !terminalView.isProcessRunning {
            terminalView.startProcess()
        }
    }

    func deactivate() {
        // Keep the PTY running across mode switches; the user expects
        // to come back to a live session, not a fresh shell.
    }

    func windowDidShow() {
        terminalView.resetRestartGovernor()
        terminalView.writeSessionSeparator()
    }

    func windowDidHide() {
        // No-op; logging continues if enabled.
    }

    func updateAppPreferences(fontFamily: String, fontSize: Double, logInput: Bool) {
        viewConfig.fontFamily = fontFamily
        viewConfig.fontSize = fontSize
        viewConfig.logInput = logInput
        terminalView.updateConfig(viewConfig)
    }

    /// Returns the first responder when this mode is active, so the
    /// host window can focus the terminal widget directly.
    func preferredFirstResponder() -> NSResponder? {
        terminalView.terminal
    }
}

enum TerminalModeFactory: ModeFactory {
    static let typeId = "terminal"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        guard let command = instance.raw["command"] as? String, !command.isEmpty else {
            throw ModeError.missingField("command")
        }
        let args = (instance.raw["args"] as? [String]) ?? []
        let viewConfig = TerminalViewConfig(
            command: command,
            args: args,
            fontFamily: (instance.raw["fontFamily"] as? String) ?? appPrefs.fontFamily,
            fontSize: (instance.raw["fontSize"] as? Double) ?? appPrefs.fontSize,
            logInput: (instance.raw["logInput"] as? Bool) ?? appPrefs.logInput
        )
        return TerminalMode(
            id: instance.id,
            displayName: (instance.raw["displayName"] as? String) ?? instance.id.capitalized,
            viewConfig: viewConfig
        )
    }
}
