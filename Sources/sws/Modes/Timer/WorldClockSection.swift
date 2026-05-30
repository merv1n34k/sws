import AppKit

final class WorldClockSection: NSView {
    private let mode: TimerMode
    private var rows: [(label: String, tz: TimeZone, value: NSTextField)] = []
    private let stack = NSStackView()
    private var timer: Timer?

    init(mode: TimerMode) {
        self.mode = mode
        super.init(frame: .zero)

        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        buildRows()
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
        tick()
    }

    private func buildRows() {
        for sub in stack.arrangedSubviews { stack.removeArrangedSubview(sub); sub.removeFromSuperview() }
        rows.removeAll()

        for raw in mode.worldClocks {
            guard let tz = parseTimeZone(raw) else {
                NSLog("SWS: invalid time zone '\(raw)'")
                continue
            }
            let label = NSTextField(labelWithString: raw)
            label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            label.textColor = .secondaryLabelColor

            let value = NSTextField(labelWithString: "--:--:--")
            value.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .regular)
            value.textColor = .white

            let row = NSStackView(views: [label, value])
            row.orientation = .horizontal
            row.distribution = .equalSpacing
            row.alignment = .firstBaseline

            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            rows.append((raw, tz, value))
        }
    }

    private func startUITimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
        tick()
    }

    private func tick() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm:ss"
        for row in rows {
            formatter.timeZone = row.tz
            row.value.stringValue = formatter.string(from: now)
        }
    }

    /// Accepts: "UTC", "UTC+3", "UTC-08", "UTC+5:30", or any value
    /// understood by TimeZone(identifier:) like "America/New_York".
    private func parseTimeZone(_ raw: String) -> TimeZone? {
        let s = raw.trimmingCharacters(in: .whitespaces)

        if s.uppercased().hasPrefix("UTC") {
            let rest = s.dropFirst(3)
            if rest.isEmpty { return TimeZone(secondsFromGMT: 0) }
            guard let first = rest.first, first == "+" || first == "-" else { return nil }
            let body = rest.dropFirst()
            let sign = first == "+" ? 1 : -1
            let parts = body.split(separator: ":")
            let hours = Int(parts[0]) ?? -1
            let minutes = parts.count > 1 ? (Int(parts[1]) ?? -1) : 0
            guard hours >= 0, minutes >= 0 else { return nil }
            return TimeZone(secondsFromGMT: sign * (hours * 3600 + minutes * 60))
        }

        return TimeZone(identifier: s)
    }
}
