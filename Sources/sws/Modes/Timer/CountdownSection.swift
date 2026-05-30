import AppKit

final class CountdownSection: NSView {
    private let mode: TimerMode
    private let input = NSTextField()
    private let display = NSTextField(labelWithString: "00:00")
    private let hint = NSTextField(labelWithString: "e.g. 5m, 90s, 1h30m, 1:30:00")
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private var timer: Timer?

    init(mode: TimerMode) {
        self.mode = mode
        super.init(frame: .zero)

        input.placeholderString = "duration"
        input.font = NSFont.systemFont(ofSize: 14)
        input.alignment = .center
        input.translatesAutoresizingMaskIntoConstraints = false
        input.target = self
        input.action = #selector(submitInput)
        addSubview(input)

        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)

        display.font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .light)
        display.textColor = .white
        display.alignment = .center
        display.translatesAutoresizingMaskIntoConstraints = false
        addSubview(display)

        startButton.target = self; startButton.action = #selector(startTapped)
        pauseButton.target = self; pauseButton.action = #selector(pauseTapped)
        resetButton.target = self; resetButton.action = #selector(resetTapped)

        let buttons = NSStackView(views: [startButton, pauseButton, resetButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttons)

        NSLayoutConstraint.activate([
            input.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            input.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            input.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),

            hint.topAnchor.constraint(equalTo: input.bottomAnchor, constant: 2),
            hint.leadingAnchor.constraint(equalTo: leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: trailingAnchor),

            display.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            display.leadingAnchor.constraint(equalTo: leadingAnchor),
            display.trailingAnchor.constraint(equalTo: trailingAnchor),

            buttons.topAnchor.constraint(equalTo: display.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit { timer?.invalidate() }

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
        if input.stringValue.isEmpty {
            input.stringValue = DurationParser.format(mode.countdownTotal)
        }
    }

    private func startUITimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func tick() {
        updateDisplay()
        if mode.countdownIsRunning && mode.countdownRemaining <= 0 {
            mode.countdownDidComplete()
            updateDisplay()
            updateButtons()
        }
    }

    private func updateDisplay() {
        display.stringValue = DurationParser.format(mode.countdownRemaining)
    }

    private func updateButtons() {
        if mode.countdownIsRunning {
            startButton.isEnabled = false
            pauseButton.title = "Pause"
            pauseButton.isEnabled = true
            resetButton.isEnabled = true
        } else if mode.countdownIsPaused {
            startButton.isEnabled = false
            pauseButton.title = "Resume"
            pauseButton.isEnabled = true
            resetButton.isEnabled = true
        } else {
            startButton.isEnabled = true
            pauseButton.isEnabled = false
            pauseButton.title = "Pause"
            resetButton.isEnabled = mode.countdownRemaining != mode.countdownTotal
        }
    }

    @objc private func submitInput() {
        startTapped()
    }

    @objc private func startTapped() {
        guard let total = DurationParser.parse(input.stringValue) else {
            input.stringValue = ""
            input.placeholderString = "invalid — try 5m, 1:30, 90s"
            return
        }
        input.placeholderString = "duration"
        mode.countdownStart(total: total)
        updateButtons()
        updateDisplay()
    }

    @objc private func pauseTapped() {
        mode.countdownPauseResume()
        updateButtons()
    }

    @objc private func resetTapped() {
        mode.countdownReset()
        updateButtons()
        updateDisplay()
    }
}
