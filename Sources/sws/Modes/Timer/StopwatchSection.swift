import AppKit

final class StopwatchSection: NSView {
    private let mode: TimerMode
    private let display = NSTextField(labelWithString: "00:00.00")
    private let startStopButton = NSButton(title: "Start", target: nil, action: nil)
    private let lapButton = NSButton(title: "Lap", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let lapList = NSTextField(labelWithString: "")
    private var timer: Timer?

    init(mode: TimerMode) {
        self.mode = mode
        super.init(frame: .zero)

        display.font = NSFont.monospacedDigitSystemFont(ofSize: 44, weight: .light)
        display.textColor = .white
        display.alignment = .center
        display.translatesAutoresizingMaskIntoConstraints = false
        addSubview(display)

        startStopButton.target = self
        startStopButton.action = #selector(toggleRun)
        lapButton.target = self
        lapButton.action = #selector(lap)
        resetButton.target = self
        resetButton.action = #selector(reset)

        let buttons = NSStackView(views: [startStopButton, lapButton, resetButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttons)

        lapList.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        lapList.textColor = .secondaryLabelColor
        lapList.alignment = .center
        lapList.lineBreakMode = .byTruncatingTail
        lapList.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lapList)

        NSLayoutConstraint.activate([
            display.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            display.leadingAnchor.constraint(equalTo: leadingAnchor),
            display.trailingAnchor.constraint(equalTo: trailingAnchor),

            buttons.topAnchor.constraint(equalTo: display.bottomAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor),

            lapList.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 12),
            lapList.leadingAnchor.constraint(equalTo: leadingAnchor),
            lapList.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        timer?.invalidate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startUITimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func refresh() {
        updateDisplay()
        updateButtons()
        updateLaps()
    }

    private func startUITimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func updateDisplay() {
        display.stringValue = DurationParser.formatPrecise(mode.stopwatchCurrentElapsed)
    }

    private func updateButtons() {
        startStopButton.title = mode.stopwatchRunning ? "Stop" : "Start"
        lapButton.isEnabled = mode.stopwatchRunning
    }

    private func updateLaps() {
        if mode.stopwatchLaps.isEmpty {
            lapList.stringValue = ""
            return
        }
        let recent = mode.stopwatchLaps.suffix(3).enumerated().map { idx, t in
            "L\(mode.stopwatchLaps.count - 2 + idx): \(DurationParser.formatPrecise(t))"
        }
        lapList.stringValue = recent.joined(separator: "   ")
    }

    @objc private func toggleRun() {
        mode.stopwatchStartStop()
        updateButtons()
    }

    @objc private func lap() {
        mode.stopwatchLap()
        updateLaps()
    }

    @objc private func reset() {
        mode.stopwatchReset()
        refresh()
    }
}
