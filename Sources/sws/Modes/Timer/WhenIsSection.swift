import AppKit

final class WhenIsSection: NSView, NSTextFieldDelegate {
    private let input = NSTextField()
    private let hint = NSTextField(labelWithString: "e.g. \"20 hours from now\", \"next saturday\", \"3 weekdays from monday\"")
    private let resolvedLabel = NSTextField(labelWithString: "—")
    private let countdownLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var resolved: Date?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .medium
        return f
    }()

    init() {
        super.init(frame: .zero)
        buildLayout()
        wire()
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

    private func buildLayout() {
        input.placeholderString = "phrase"
        input.font = NSFont.systemFont(ofSize: 14)
        input.alignment = .center

        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.maximumNumberOfLines = 2

        resolvedLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        resolvedLabel.textColor = .white
        resolvedLabel.alignment = .center
        resolvedLabel.maximumNumberOfLines = 2

        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        countdownLabel.textColor = .secondaryLabelColor
        countdownLabel.alignment = .center

        let stack = NSStackView(views: [input, hint, resolvedLabel, countdownLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    private func wire() {
        input.target = self
        input.action = #selector(inputChanged)
        input.delegate = self
    }

    func controlTextDidChange(_ notification: Notification) {
        resolve()
    }

    private func startUITimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func inputChanged() {
        resolve()
    }

    private func resolve() {
        resolved = DatePhraseParser.parse(input.stringValue)
        if let r = resolved {
            resolvedLabel.stringValue = dateFormatter.string(from: r)
        } else if input.stringValue.isEmpty {
            resolvedLabel.stringValue = "—"
            countdownLabel.stringValue = ""
        } else {
            resolvedLabel.stringValue = "(couldn't parse)"
            countdownLabel.stringValue = ""
        }
        updateCountdown()
    }

    private func updateCountdown() {
        guard let r = resolved else { return }
        let diff = r.timeIntervalSinceNow
        let abs = Swift.abs(diff)
        let text: String
        if abs < 60 {
            text = String(format: "%.0f seconds", abs)
        } else if abs < 3600 {
            text = String(format: "%.1f minutes", abs / 60)
        } else if abs < 86_400 {
            text = String(format: "%.1f hours", abs / 3600)
        } else {
            text = String(format: "%.1f days", abs / 86_400)
        }
        countdownLabel.stringValue = diff >= 0 ? "in \(text)" : "\(text) ago"
    }
}
