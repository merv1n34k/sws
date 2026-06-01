import AppKit

/// App + mode preferences in a single scrollable window. Sections
/// (General, Clipboard, Modes) are stacked vertically.
final class PreferencesWindow: NSWindow {
    private var config: SWSConfig
    var onConfigChanged: ((SWSConfig) -> Void)?

    // General
    private let fontFamilyField = NSTextField()
    private let fontSizeField = NSTextField()
    private let rememberSizeCheck = NSButton(checkboxWithTitle: "Remember window size", target: nil, action: nil)
    private let logInputCheck = NSButton(checkboxWithTitle: "Log terminal output to ~/.sws.log", target: nil, action: nil)

    // Clipboard
    private let clipMaxEntriesField = NSTextField()
    private let clipMaxBytesField = NSTextField()

    // Modes
    private var defaultPopup = NSPopUpButton()
    private var hotkeyFields: [String: NSTextField] = [:]   // mode id → text field

    init(config: SWSConfig) {
        self.config = config
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = "SWS Preferences"
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 460, height: 420)
        self.center()
        setupUI()
        loadValues()
    }

    // MARK: - Layout

    private func setupUI() {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

        let general = section(title: "General", views: [
            row("Font", control: fontFamilyField, placeholder: "Menlo"),
            row("Font Size", control: fontSizeField, placeholder: "14"),
            rememberSizeCheck,
            logInputCheck,
        ])

        let clipboard = section(title: "Clipboard", views: [
            row("Max entries", control: clipMaxEntriesField, placeholder: "500"),
            row("Max bytes per entry", control: clipMaxBytesField, placeholder: "1000000"),
            hint("Higher values keep more history at the cost of disk. Both fields accept any positive integer."),
        ])

        let modes = section(title: "Modes & Hotkeys", views: [
            defaultRow(),
            modeList(),
            hint("Hotkey format: \"<modifiers>+<key>\" e.g. shift+option+a. Modifiers: shift, option, command, control. Leave blank to disable a mode's hotkey."),
            openConfigButton(),
        ])

        let stack = NSStackView(views: [general, clipboard, modes])
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let buttons = makeFooter()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            buttons.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 24),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
        ])

        scroll.documentView = content
        let host = NSView(frame: contentRect(forFrameRect: frame))
        host.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: host.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
        contentView = host
    }

    private func section(title: String, views: [NSView]) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let inner = NSStackView(views: views)
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 8
        inner.translatesAutoresizingMaskIntoConstraints = false

        let group = NSStackView(views: [label, inner])
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 8
        group.translatesAutoresizingMaskIntoConstraints = false
        return group
    }

    private func row(_ title: String, control: NSTextField, placeholder: String? = nil) -> NSView {
        let l = NSTextField(labelWithString: title + ":")
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 160).isActive = true
        if let p = placeholder { control.placeholderString = p }
        control.widthAnchor.constraint(equalToConstant: 240).isActive = true
        let row = NSStackView(views: [l, control])
        row.spacing = 8
        row.alignment = .firstBaseline
        return row
    }

    private func hint(_ text: String) -> NSView {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.preferredMaxLayoutWidth = 460
        return l
    }

    private func defaultRow() -> NSView {
        let l = NSTextField(labelWithString: "Default mode:")
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 160).isActive = true
        defaultPopup = NSPopUpButton()
        for cfg in config.modes {
            defaultPopup.addItem(withTitle: displayName(for: cfg))
            defaultPopup.lastItem?.representedObject = cfg.id
        }
        defaultPopup.widthAnchor.constraint(equalToConstant: 240).isActive = true
        let row = NSStackView(views: [l, defaultPopup])
        row.spacing = 8
        row.alignment = .firstBaseline
        return row
    }

    private func modeList() -> NSView {
        let table = NSStackView()
        table.orientation = .vertical
        table.alignment = .leading
        table.spacing = 4

        let header = NSStackView(views: [
            modeHeader("Mode", width: 160, alignment: .right),
            modeHeader("Hotkey", width: 240, alignment: .left),
        ])
        header.spacing = 8
        table.addArrangedSubview(header)

        for cfg in config.modes {
            let l = NSTextField(labelWithString: displayName(for: cfg))
            l.alignment = .right
            l.widthAnchor.constraint(equalToConstant: 160).isActive = true

            let field = NSTextField()
            field.placeholderString = "shift+option+letter"
            field.widthAnchor.constraint(equalToConstant: 240).isActive = true
            hotkeyFields[cfg.id] = field

            let row = NSStackView(views: [l, field])
            row.spacing = 8
            row.alignment = .firstBaseline
            table.addArrangedSubview(row)
        }
        return table
    }

    private func modeHeader(_ s: String, width: CGFloat, alignment: NSTextAlignment) -> NSView {
        let l = NSTextField(labelWithString: s)
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        l.textColor = .secondaryLabelColor
        l.alignment = alignment
        l.widthAnchor.constraint(equalToConstant: width).isActive = true
        return l
    }

    private func openConfigButton() -> NSView {
        let btn = NSButton(title: "Open ~/.config/sws/config.json", target: self, action: #selector(openConfig))
        btn.bezelStyle = .rounded
        return btn
    }

    private func makeFooter() -> NSView {
        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1B}"
        let stack = NSStackView(views: [cancel, save])
        stack.spacing = 8
        return stack
    }

    // MARK: - Values

    private func loadValues() {
        fontFamilyField.stringValue = config.fontFamily
        fontSizeField.stringValue = String(Int(config.fontSize))
        rememberSizeCheck.state = config.rememberSize ? .on : .off
        logInputCheck.state = config.logInput ? .on : .off

        clipMaxEntriesField.stringValue = "\(config.clipboardMaxEntries)"
        clipMaxBytesField.stringValue = "\(config.clipboardMaxEntryBytes)"

        for cfg in config.modes {
            hotkeyFields[cfg.id]?.stringValue = describe(cfg.hotkey)
        }
        if let idx = config.modes.firstIndex(where: { $0.id == config.defaultMode }) {
            defaultPopup.selectItem(at: idx)
        }
    }

    @objc private func save() {
        config.fontFamily = fontFamilyField.stringValue
        if let size = Double(fontSizeField.stringValue), size > 0 {
            config.fontSize = size
        }
        config.rememberSize = rememberSizeCheck.state == .on
        config.logInput = logInputCheck.state == .on

        if let n = Int(clipMaxEntriesField.stringValue), n > 0 {
            config.clipboardMaxEntries = n
        }
        if let n = Int(clipMaxBytesField.stringValue), n >= 1024 {
            config.clipboardMaxEntryBytes = n
        }

        if let pickedID = defaultPopup.selectedItem?.representedObject as? String {
            config.defaultMode = pickedID
        }

        // Rewrite each mode's hotkey (and its raw["hotkey"] mirror) from
        // the text-field input. Parser tolerates "+", whitespace, and
        // arbitrary case.
        for i in 0..<config.modes.count {
            let id = config.modes[i].id
            guard let field = hotkeyFields[id] else { continue }
            let parsed = parseHotkey(field.stringValue)
            config.modes[i].hotkey = parsed
            if let p = parsed {
                config.modes[i].raw["hotkey"] = ["key": p.key, "modifiers": p.modifiers]
            } else {
                config.modes[i].raw.removeValue(forKey: "hotkey")
            }
        }

        onConfigChanged?(config)
        close()
    }

    @objc private func cancel() { close() }

    @objc private func openConfig() {
        NSWorkspace.shared.open(SWSConfig.configFile)
    }

    // MARK: - Helpers

    private func displayName(for cfg: ModeConfig) -> String {
        if let n = cfg.raw["displayName"] as? String { return n }
        return cfg.id.prefix(1).uppercased() + cfg.id.dropFirst()
    }

    private func describe(_ s: ShortcutConfig?) -> String {
        guard let s = s else { return "" }
        let mods = s.modifiers.map { $0.lowercased() }.joined(separator: "+")
        return mods.isEmpty ? s.key : "\(mods)+\(s.key)"
    }

    private func parseHotkey(_ raw: String) -> ShortcutConfig? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(whereSeparator: { "+ ".contains($0) }).map { $0.lowercased() }
        guard let last = parts.last else { return nil }
        let mods = parts.dropLast().filter { ["shift", "option", "command", "control", "alt", "cmd", "ctrl"].contains($0) }
        // Normalize a couple of common aliases to the canonical names
        // the hotkey manager understands.
        let normalized: [String] = mods.map {
            switch $0 {
            case "alt": return "option"
            case "cmd": return "command"
            case "ctrl": return "control"
            default: return $0
            }
        }
        return ShortcutConfig(key: String(last), modifiers: normalized)
    }
}
