import AppKit

final class TimerView: NSView {
    private let mode: TimerMode
    private let segmented: NSSegmentedControl
    private let container: NSView
    private let stopwatch: StopwatchSection
    private let countdown: CountdownSection
    private let pomodoro: PomodoroSection
    private let worldClock: WorldClockSection
    private let whenIs: WhenIsSection

    init(mode: TimerMode) {
        self.mode = mode
        self.segmented = NSSegmentedControl(
            labels: ["Stopwatch", "Countdown", "Pomodoro", "World", "When-is"],
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        self.container = NSView()
        self.stopwatch = StopwatchSection(mode: mode)
        self.countdown = CountdownSection(mode: mode)
        self.pomodoro = PomodoroSection(mode: mode)
        self.worldClock = WorldClockSection(mode: mode)
        self.whenIs = WhenIsSection()

        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        segmented.target = self
        segmented.action = #selector(subModeChanged(_:))
        segmented.segmentStyle = .texturedRounded
        segmented.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmented)

        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            segmented.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])

        selectSegment(for: mode.currentSubMode)
        installCurrentSection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func refresh() {
        selectSegment(for: mode.currentSubMode)
        installCurrentSection()
    }

    private func selectSegment(for sub: TimerMode.SubMode) {
        switch sub {
        case .stopwatch:  segmented.selectedSegment = 0
        case .countdown:  segmented.selectedSegment = 1
        case .pomodoro:   segmented.selectedSegment = 2
        case .worldClock: segmented.selectedSegment = 3
        case .whenIs:     segmented.selectedSegment = 4
        }
    }

    @objc private func subModeChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: mode.currentSubMode = .stopwatch
        case 1: mode.currentSubMode = .countdown
        case 2: mode.currentSubMode = .pomodoro
        case 3: mode.currentSubMode = .worldClock
        case 4: mode.currentSubMode = .whenIs
        default: return
        }
        installCurrentSection()
    }

    private func installCurrentSection() {
        for sub in container.subviews { sub.removeFromSuperview() }
        let section: NSView
        switch mode.currentSubMode {
        case .stopwatch:
            stopwatch.refresh()
            section = stopwatch
        case .countdown:
            countdown.refresh()
            section = countdown
        case .pomodoro:
            pomodoro.refresh()
            section = pomodoro
        case .worldClock:
            worldClock.refresh()
            section = worldClock
        case .whenIs:
            section = whenIs
        }
        section.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(section)
        NSLayoutConstraint.activate([
            section.topAnchor.constraint(equalTo: container.topAnchor),
            section.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            section.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }
}
