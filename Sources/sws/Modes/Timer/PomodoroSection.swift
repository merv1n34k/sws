import AppKit

final class PomodoroSection: NSView {
    private let mode: TimerMode
    private let phaseLabel = NSTextField(labelWithString: "Work")
    private let display = NSTextField(labelWithString: "25:00")
    private let cycleLabel = NSTextField(labelWithString: "0 cycles")
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let skipButton = NSButton(title: "Skip", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private var timer: Timer?

    init(mode: TimerMode) {
        self.mode = mode
        super.init(frame: .zero)
        buildLayout()
        wire()
        refresh()
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
    }

    private func buildLayout() {
        phaseLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        phaseLabel.textColor = .secondaryLabelColor
        phaseLabel.alignment = .center

        display.font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .light)
        display.textColor = .white
        display.alignment = .center

        cycleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        cycleLabel.textColor = .secondaryLabelColor
        cycleLabel.alignment = .center

        for b in [startButton, pauseButton, skipButton, resetButton] {
            b.bezelStyle = .rounded
        }

        let buttons = NSStackView(views: [startButton, pauseButton, skipButton, resetButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually

        let stack = NSStackView(views: [phaseLabel, display, cycleLabel, buttons])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func wire() {
        startButton.target = self; startButton.action = #selector(start)
        pauseButton.target = self; pauseButton.action = #selector(pause)
        skipButton.target = self; skipButton.action = #selector(skip)
        resetButton.target = self; resetButton.action = #selector(reset)
    }

    private func startUITimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        updateDisplay()
        if mode.pomodoroIsRunning && mode.pomodoroRemaining <= 0 {
            mode.pomodoroDidComplete()
        }
        updateButtons()
    }

    private func updateDisplay() {
        display.stringValue = DurationParser.format(mode.pomodoroRemaining)
        phaseLabel.stringValue = mode.pomodoroPhase == .work ? "Work" : "Break"
        cycleLabel.stringValue = "\(mode.pomodoroCompletedCycles) cycle\(mode.pomodoroCompletedCycles == 1 ? "" : "s") completed"
    }

    private func updateButtons() {
        if mode.pomodoroIsRunning {
            startButton.isEnabled = false
            pauseButton.title = "Pause"; pauseButton.isEnabled = true
            skipButton.isEnabled = true
            resetButton.isEnabled = true
        } else if mode.pomodoroIsPaused {
            startButton.isEnabled = false
            pauseButton.title = "Resume"; pauseButton.isEnabled = true
            skipButton.isEnabled = true
            resetButton.isEnabled = true
        } else {
            startButton.isEnabled = true
            pauseButton.isEnabled = false; pauseButton.title = "Pause"
            skipButton.isEnabled = false
            resetButton.isEnabled = mode.pomodoroCompletedCycles > 0
        }
    }

    @objc private func start() { mode.pomodoroStart(); refresh() }
    @objc private func pause() { mode.pomodoroPauseResume(); refresh() }
    @objc private func skip() { mode.pomodoroSkipPhase(); refresh() }
    @objc private func reset() { mode.pomodoroReset(); refresh() }
}
