import AppKit

final class PreferencesWindow: NSWindow {
    private var config: SWSConfig
    var onConfigChanged: ((SWSConfig) -> Void)?

    private let commandField = NSTextField()
    private let argsField = NSTextField()
    private let hotkeyKeyField = NSTextField()
    private let hotkeyModsField = NSTextField()
    private let fontFamilyField = NSTextField()
    private let fontSizeField = NSTextField()
    private let rememberSizeCheck = NSButton(checkboxWithTitle: "Remember window size", target: nil, action: nil)
    private let logInputCheck = NSButton(checkboxWithTitle: "Log input to ~/.sws.log", target: nil, action: nil)

    init(config: SWSConfig) {
        self.config = config
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
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

        let labels = ["Command:", "Arguments:", "Hotkey:", "Modifiers:", "Font:", "Font Size:"]
        let fields: [NSTextField] = [commandField, argsField, hotkeyKeyField, hotkeyModsField, fontFamilyField, fontSizeField]
        let placeholders = ["/usr/bin/bc", "-l", "s", "shift, option", "Menlo", "14"]

        var y = 290.0
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
        commandField.stringValue = config.command
        argsField.stringValue = config.args.joined(separator: " ")
        hotkeyKeyField.stringValue = config.shortcut.key
        hotkeyModsField.stringValue = config.shortcut.modifiers.joined(separator: ", ")
        fontFamilyField.stringValue = config.fontFamily
        fontSizeField.stringValue = String(Int(config.fontSize))
        rememberSizeCheck.state = config.rememberSize ? .on : .off
        logInputCheck.state = config.logInput ? .on : .off
    }

    @objc private func save() {
        config.command = commandField.stringValue
        config.args = argsField.stringValue
            .split(separator: " ")
            .map(String.init)
        config.shortcut.key = hotkeyKeyField.stringValue.lowercased()
        config.shortcut.modifiers = hotkeyModsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        config.fontFamily = fontFamilyField.stringValue
        if let size = Double(fontSizeField.stringValue), size > 0 {
            config.fontSize = size
        }
        config.rememberSize = rememberSizeCheck.state == .on
        config.logInput = logInputCheck.state == .on

        config.save()
        onConfigChanged?(config)
        close()
    }

    @objc private func cancel() {
        close()
    }
}
