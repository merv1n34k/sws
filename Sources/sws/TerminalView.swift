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
    private var logHandle: FileHandle?
    private var pendingSeparator: String?

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
    }

    private var lastLoggedLine = 0
    private var logDebounce: DispatchWorkItem?

    // MARK: - Session logging

    private func setupLogging() {
        terminal.onDataReceived = { [weak self] _ in
            self?.scheduleLogFlush()
        }
    }

    func writeSessionSeparator() {
        guard config.logInput else { return }
        let df = DateFormatter()
        df.dateFormat = "yy/MM/dd HH:mm:ss"
        pendingSeparator = "\n[\(df.string(from: Date()))]\n"
    }

    private func scheduleLogFlush() {
        logDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flushNewLines()
        }
        logDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func flushNewLines() {
        let term = terminal.getTerminal()
        let topRow = term.getTopVisibleRow()
        let currentLine = topRow + term.getCursorLocation().y

        if currentLine < lastLoggedLine { lastLoggedLine = 0 }
        guard currentLine > lastLoggedLine else { return }

        if let sep = pendingSeparator, let sepData = sep.data(using: .utf8) {
            pendingSeparator = nil
            writeToLog(sepData)
        }

        for i in lastLoggedLine ..< currentLine {
            if let line = term.getLine(row: i - topRow) {
                let text = line.translateToString(trimRight: true)
                writeToLog(Data((text + "\n").utf8))
            }
        }
        lastLoggedLine = currentLine
    }

    private func writeToLog(_ data: Data) {
        if logHandle == nil {
            let path = SWSConfig.logFile.path
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }
            logHandle = FileHandle(forWritingAtPath: path)
            logHandle?.seekToEndOfFile()
        }
        logHandle?.write(data)
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
