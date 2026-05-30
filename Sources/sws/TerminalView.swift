import AppKit
import SwiftTerm

// Subclass to hide scroller, silence bell, and capture output
final class SilentTerminalView: LocalProcessTerminalView {
    var onDataReceived: ((Data) -> Void)?

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

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onDataReceived?(Data(slice))
    }
}

final class TerminalView: NSView, LocalProcessTerminalViewDelegate {
    let terminal: SilentTerminalView
    private var config: SWSConfig
    private var processRunning = false
    private var dragOrigin: NSPoint?

    // Logging
    private var logHandle: FileHandle?
    private var pendingSeparator: String?
    private let logQueue = DispatchQueue(label: "sws.log", qos: .utility)

    // Respawn governor
    private var restartTimestamps: [Date] = []
    private let restartLimit = 3
    private let restartWindow: TimeInterval = 10
    private var restartHalted = false

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
            setupLogging()
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
        if config.logInput && terminal.onDataReceived == nil {
            setupLogging()
        }
        // Reset respawn governor when user touches preferences
        restartTimestamps.removeAll()
        restartHalted = false
    }

    /// Called by AppDelegate when the window is shown — resets the respawn cap
    /// so the user gets a fresh allowance per session.
    func resetRestartGovernor() {
        restartTimestamps.removeAll()
        restartHalted = false
    }

    // MARK: - Session logging

    private func setupLogging() {
        terminal.onDataReceived = { [weak self] data in
            self?.appendToLog(data)
        }
    }

    func writeSessionSeparator() {
        guard config.logInput else { return }
        let df = DateFormatter()
        df.dateFormat = "yy/MM/dd HH:mm:ss"
        let sep = "\n[\(df.string(from: Date()))]\n"
        logQueue.async { [weak self] in
            self?.pendingSeparator = sep
        }
    }

    private func appendToLog(_ data: Data) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let cleaned = TerminalView.stripAnsi(data)
            guard !cleaned.isEmpty || self.pendingSeparator != nil else { return }

            self.ensureLogHandle()
            if let sep = self.pendingSeparator, let sepData = sep.data(using: .utf8) {
                self.pendingSeparator = nil
                self.logHandle?.write(sepData)
            }
            if !cleaned.isEmpty {
                self.logHandle?.write(cleaned)
            }
        }
    }

    private func ensureLogHandle() {
        guard logHandle == nil else { return }
        let path = SWSConfig.logFile.path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        logHandle = FileHandle(forWritingAtPath: path)
        logHandle?.seekToEndOfFile()
    }

    /// Strips ANSI escape sequences and bare CRs from a stream of terminal output.
    /// Public-for-tests; the implementation is deliberately conservative — it covers
    /// CSI (`ESC [ ... letter`), OSC (`ESC ] ... BEL`/`ST`), and a few simple
    /// two-byte escapes; anything else passes through.
    static func stripAnsi(_ data: Data) -> Data {
        var out = Data()
        out.reserveCapacity(data.count)
        var i = 0
        let bytes = [UInt8](data)
        while i < bytes.count {
            let b = bytes[i]
            if b == 0x1B && i + 1 < bytes.count {
                let next = bytes[i + 1]
                if next == 0x5B { // ESC [   CSI
                    i += 2
                    while i < bytes.count {
                        let c = bytes[i]
                        i += 1
                        if (0x40...0x7E).contains(c) { break }
                    }
                    continue
                }
                if next == 0x5D { // ESC ]   OSC — terminated by BEL or ST (ESC \)
                    i += 2
                    while i < bytes.count {
                        let c = bytes[i]
                        if c == 0x07 { i += 1; break }
                        if c == 0x1B && i + 1 < bytes.count && bytes[i + 1] == 0x5C {
                            i += 2; break
                        }
                        i += 1
                    }
                    continue
                }
                // Two-byte escapes: ESC (B, ESC =, ESC >, ESC c, ESC 7, ESC 8, etc.
                i += 2
                continue
            }
            if b == 0x0D { // bare CR — terminals overwrite the line; drop it
                i += 1
                continue
            }
            out.append(b)
            i += 1
        }
        return out
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
                // tmux-style: copy selection to clipboard on mouse release
                if inTerminal, let text = self.terminal.getSelection(), !text.isEmpty {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
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

        let now = Date()
        restartTimestamps.append(now)
        restartTimestamps.removeAll { now.timeIntervalSince($0) > restartWindow }

        if restartHalted { return }

        if restartTimestamps.count > restartLimit {
            restartHalted = true
            let msg = "\r\n\u{1B}[31mSWS: process exited \(restartLimit) times in \(Int(restartWindow))s — check command in Preferences\u{1B}[0m\r\n"
            terminal.feed(text: msg)
            return
        }
        onProcessExit?()
    }
}
