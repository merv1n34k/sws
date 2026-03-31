import AppKit

final class TerminalView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let pty = PTY()
    private var config: SWSConfig

    var isProcessRunning: Bool { pty.isRunning }
    private var currentInputLine = ""
    private var dragOrigin: NSPoint?

    var onProcessExit: (() -> Void)?

    init(config: SWSConfig) {
        self.config = config
        super.init(frame: .zero)
        setupUI()
        setupPTY()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let font = NSFont(name: config.fontFamily, size: config.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
        textView.textColor = NSColor(white: 0.95, alpha: 1.0)
        textView.insertionPointColor = NSColor(white: 0.95, alpha: 1.0)
        textView.font = font
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        scrollView.frame = bounds
        addSubview(scrollView)
    }

    private func setupPTY() {
        pty.onOutput = { [weak self] data in
            self?.appendOutput(data)
        }
        pty.onExit = { [weak self] in
            self?.appendText("\n[Process exited]\n")
            self?.onProcessExit?()
        }
    }

    func startProcess() {
        pty.start(command: config.command, args: config.args)
        updatePTYSize()
    }

    func stopProcess() {
        pty.stop()
    }

    func updateConfig(_ newConfig: SWSConfig) {
        config = newConfig
        let font = NSFont(name: config.fontFamily, size: config.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)
        textView.font = font
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
        updatePTYSize()
    }

    private func updatePTYSize() {
        guard let font = textView.font else { return }
        let charWidth = font.advancement(forGlyph: font.glyph(withName: "M")).width
        let lineHeight = font.ascender - font.descender + font.leading
        guard charWidth > 0, lineHeight > 0 else { return }

        let cols = UInt16(max(1, bounds.width / charWidth))
        let rows = UInt16(max(1, bounds.height / lineHeight))
        pty.resize(cols: cols, rows: rows)
    }

    // Strip basic ANSI escape sequences
    private func stripANSI(_ string: String) -> String {
        // Remove CSI sequences: ESC[ ... final_byte
        var result = string
        while let range = result.range(of: "\u{1B}\\[[0-9;]*[A-Za-z]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove OSC sequences: ESC] ... ST
        while let range = result.range(of: "\u{1B}\\][^\u{07}\u{1B}]*(\u{07}|\u{1B}\\\\)", options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }

    private func appendOutput(_ data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return }
        let text = stripANSI(raw)
        processText(text)
    }

    private func processText(_ text: String) {
        let storage = textView.textStorage!
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(white: 0.95, alpha: 1.0),
            .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        ]

        for ch in text {
            switch ch {
            case "\u{08}": // backspace
                let len = storage.length
                if len > 0 {
                    storage.deleteCharacters(in: NSRange(location: len - 1, length: 1))
                }
            case "\r": // carriage return — move to start of current line
                let str = storage.string
                if let nlRange = str.range(of: "\n", options: .backwards) {
                    let afterNL = str.distance(from: str.startIndex, to: nlRange.upperBound)
                    let deleteLen = storage.length - afterNL
                    if deleteLen > 0 {
                        storage.deleteCharacters(in: NSRange(location: afterNL, length: deleteLen))
                    }
                } else {
                    // No newline — clear everything
                    storage.deleteCharacters(in: NSRange(location: 0, length: storage.length))
                }
            case "\u{07}": // bell — ignore
                break
            default:
                storage.append(NSAttributedString(string: String(ch), attributes: attrs))
            }
        }
        textView.scrollToEndOfDocument(nil)
    }

    private func appendText(_ text: String) {
        let storage = textView.textStorage!
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(white: 0.95, alpha: 1.0),
            .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        ]
        storage.append(NSAttributedString(string: text, attributes: attrs))
        textView.scrollToEndOfDocument(nil)
    }

    // Option+drag to move window
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            dragOrigin = event.locationInWindow
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if let origin = dragOrigin, let win = window {
            let current = event.locationInWindow
            var frame = win.frame
            frame.origin.x += current.x - origin.x
            frame.origin.y += current.y - origin.y
            win.setFrameOrigin(frame.origin)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if dragOrigin != nil {
            dragOrigin = nil
        } else {
            super.mouseUp(with: event)
        }
    }

    // Handle keyboard input
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard pty.isRunning else { return }

        if event.modifierFlags.contains(.control) {
            // Ctrl+key combos
            if let chars = event.charactersIgnoringModifiers, let c = chars.unicodeScalars.first {
                let code = c.value
                // Ctrl+A=1 .. Ctrl+Z=26
                if code >= UInt32(Character("a").asciiValue!), code <= UInt32(Character("z").asciiValue!) {
                    let ctrl = code - UInt32(Character("a").asciiValue!) + 1
                    pty.write(Data([UInt8(ctrl)]))
                    return
                }
            }
        }

        if let chars = event.characters {
            if config.logInput {
                trackInput(chars)
            }
            pty.write(chars)
        }
    }

    private func trackInput(_ chars: String) {
        for ch in chars {
            if ch == "\r" || ch == "\n" {
                logLine(currentInputLine)
                currentInputLine = ""
            } else if ch == "\u{7F}" || ch == "\u{08}" {
                if !currentInputLine.isEmpty {
                    currentInputLine.removeLast()
                }
            } else if !ch.isASCII || ch >= " " {
                currentInputLine.append(ch)
            }
        }
    }

    private func logLine(_ line: String) {
        guard !line.isEmpty else { return }
        let logFile = SWSConfig.logFile
        let entry = line + "\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    // Ensure we get key events
    override func becomeFirstResponder() -> Bool { true }
    override func resignFirstResponder() -> Bool { true }
}
