import AppKit

/// App-wide preferences only. Mode definitions (command, args,
/// hotkeys) live in ~/.config/sws/config.json under `modes` and are
/// edited there directly for now.
final class PreferencesWindow: NSWindow {
    private var config: SWSConfig
    var onConfigChanged: ((SWSConfig) -> Void)?

    private let fontFamilyField = NSTextField()
    private let fontSizeField = NSTextField()
    private let rememberSizeCheck = NSButton(checkboxWithTitle: "Remember window size", target: nil, action: nil)
    private let logInputCheck = NSButton(checkboxWithTitle: "Log terminal output to ~/.sws.log", target: nil, action: nil)

    init(config: SWSConfig) {
        self.config = config
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "SWS Preferences"
        self.isReleasedWhenClosed = false
        self.center()
        setupUI()
        loadValues()
    }

    private func setupUI() {
        let content = NSView(frame: contentRect(forFrameRect: frame))
        contentView = content

        let labels = ["Font:", "Font Size:"]
        let fields: [NSTextField] = [fontFamilyField, fontSizeField]
        let placeholders = ["Menlo", "14"]

        var y = 190.0
        for i in 0..<labels.count {
            let label = NSTextField(labelWithString: labels[i])
            label.frame = NSRect(x: 20, y: y, width: 90, height: 22)
            label.alignment = .right
            content.addSubview(label)

            let field = fields[i]
            field.frame = NSRect(x: 120, y: y, width: 280, height: 22)
            field.placeholderString = placeholders[i]
            content.addSubview(field)
            y -= 34
        }

        rememberSizeCheck.frame = NSRect(x: 120, y: y, width: 280, height: 22)
        content.addSubview(rememberSizeCheck)
        y -= 30

        logInputCheck.frame = NSRect(x: 120, y: y, width: 280, height: 22)
        content.addSubview(logInputCheck)
        y -= 40

        let hint = NSTextField(labelWithString: "Modes are configured in ~/.config/sws/config.json")
        hint.frame = NSRect(x: 20, y: y, width: 380, height: 18)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        content.addSubview(hint)
        y -= 30

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 310, y: y, width: 90, height: 30)
        content.addSubview(saveBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.frame = NSRect(x: 210, y: y, width: 90, height: 30)
        content.addSubview(cancelBtn)
    }

    private func loadValues() {
        fontFamilyField.stringValue = config.fontFamily
        fontSizeField.stringValue = String(Int(config.fontSize))
        rememberSizeCheck.state = config.rememberSize ? .on : .off
        logInputCheck.state = config.logInput ? .on : .off
    }

    @objc private func save() {
        config.fontFamily = fontFamilyField.stringValue
        if let size = Double(fontSizeField.stringValue), size > 0 {
            config.fontSize = size
        }
        config.rememberSize = rememberSizeCheck.state == .on
        config.logInput = logInputCheck.state == .on

        onConfigChanged?(config)
        close()
    }

    @objc private func cancel() {
        close()
    }
}
