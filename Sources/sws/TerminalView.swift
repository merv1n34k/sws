import AppKit
import SwiftTerm

// Subclass to hide scroller and silence bell
final class SilentTerminalView: LocalProcessTerminalView {
    override func bell(source: Terminal) {}

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        hideScroller()
    }

    override func layout() {
        super.layout()
        hideScroller()
    }

    private func hideScroller() {
        for sub in subviews where sub is NSScroller {
            sub.isHidden = true
        }
    }
}

final class TerminalView: NSView, LocalProcessTerminalViewDelegate {
    let terminal: SilentTerminalView
    private var config: SWSConfig
    private var currentInputLine = ""
    private var processRunning = false
    private var dragOrigin: NSPoint?

    var isProcessRunning: Bool { processRunning }
    var onProcessExit: (() -> Void)?

    init(config: SWSConfig) {
        self.config = config
        self.terminal = SilentTerminalView(frame: .zero)
        super.init(frame: .zero)

        let font = NSFont(name: config.fontFamily, size: config.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)
        terminal.font = font
        terminal.nativeForegroundColor = NSColor(white: 0.95, alpha: 1.0)
        terminal.nativeBackgroundColor = NSColor(white: 0.1, alpha: 1.0)
        terminal.layer?.backgroundColor = terminal.nativeBackgroundColor.cgColor
        terminal.caretColor = NSColor(white: 0.7, alpha: 1.0)
        terminal.optionAsMetaKey = true
        terminal.processDelegate = self
        terminal.getTerminal().setCursorStyle(.steadyBar)

        if config.logInput {
            installInputLogger()
        }

        installDragHandler()

        terminal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminal)

        let pad: CGFloat = 15
        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            terminal.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func startProcess() {
        processRunning = true
        terminal.startProcess(
            executable: config.command,
            args: config.args,
            environment: nil
        )
    }

    func stopProcess() {
        processRunning = false
        terminal.terminate()
    }

    func updateConfig(_ newConfig: SWSConfig) {
        config = newConfig
        let font = NSFont(name: config.fontFamily, size: config.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)
        terminal.font = font
    }

    // MARK: - Input logging

    private func installInputLogger() {
        // SwiftTerm sends data through its TerminalViewDelegate.send() method.
        // We subclass the terminal's send path by monitoring NSEvent key input.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.config.logInput,
                  self.window?.firstResponder === self.terminal else { return event }
            if let chars = event.characters {
                self.trackInput(chars)
            }
            return event
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

    // MARK: - Option+drag to move window

    private func installDragHandler() {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self, self.window?.isVisible == true else { return event }
            let loc = event.locationInWindow
            let localPoint = self.terminal.convert(loc, from: nil)
            let inTerminal = self.terminal.bounds.contains(localPoint)

            switch event.type {
            case .leftMouseDown:
                if event.modifierFlags.contains(.option) && inTerminal {
                    self.dragOrigin = event.locationInWindow
                    return nil // consume event
                }
            case .leftMouseDragged:
                if let origin = self.dragOrigin, let win = self.window {
                    let current = event.locationInWindow
                    var frame = win.frame
                    frame.origin.x += current.x - origin.x
                    frame.origin.y += current.y - origin.y
                    win.setFrameOrigin(frame.origin)
                    return nil
                }
            case .leftMouseUp:
                if self.dragOrigin != nil {
                    self.dragOrigin = nil
                    return nil
                }
                if inTerminal {
                    // Auto-copy selection to clipboard on mouse release (tmux-style)
                    DispatchQueue.main.async {
                        if let sel = self.terminal.getSelection(), !sel.isEmpty {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(sel, forType: .string)
                            self.terminal.selectNone()
                        }
                    }
                }
            default:
                break
            }
            return event
        }
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

    func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        processRunning = false
        onProcessExit?()
    }
}
