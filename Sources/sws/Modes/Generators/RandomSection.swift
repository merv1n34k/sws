import AppKit

final class RandomSection: NSView, GeneratorsSection {
    private let inputScroll = NSScrollView()
    private let inputView = NSTextView()
    private let withoutReplCheck = NSButton(checkboxWithTitle: "Without replacement", target: nil, action: nil)
    private let pickButton = NSButton(title: "Pick", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let resultField = NSTextField(labelWithString: "—")
    private let historyView = NSTextField(labelWithString: "")

    private var pickedHistory: [String] = []
    private var alreadyPicked: Set<String> = []

    init() {
        super.init(frame: .zero)
        buildLayout()
        wire()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        inputView.isEditable = true
        inputView.isSelectable = true
        inputView.drawsBackground = true
        inputView.backgroundColor = NSColor(white: 0.15, alpha: 1)
        inputView.textColor = .white
        inputView.insertionPointColor = .white
        inputView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        inputView.textContainerInset = NSSize(width: 8, height: 8)
        inputView.string = ""

        inputScroll.documentView = inputView
        inputScroll.hasVerticalScroller = true
        inputScroll.borderType = .noBorder
        inputScroll.wantsLayer = true
        inputScroll.layer?.cornerRadius = 6
        inputScroll.layer?.masksToBounds = true

        withoutReplCheck.contentTintColor = .white

        let buttonRow = NSStackView(views: [pickButton, resetButton, withoutReplCheck])
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY
        pickButton.bezelStyle = .rounded
        resetButton.bezelStyle = .rounded

        resultField.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        resultField.textColor = .white
        resultField.alignment = .center
        resultField.maximumNumberOfLines = 1

        historyView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        historyView.textColor = .secondaryLabelColor
        historyView.maximumNumberOfLines = 2
        historyView.lineBreakMode = .byTruncatingHead

        let promptLabel = label("Items (one per line)")

        let stack = NSStackView(views: [
            promptLabel,
            inputScroll,
            buttonRow,
            resultField,
            historyView,
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            inputScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            inputScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            resultField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            historyView.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func wire() {
        pickButton.target = self
        pickButton.action = #selector(pick)
        resetButton.target = self
        resetButton.action = #selector(reset)
    }

    func refresh() { /* no auto-refresh */ }

    @objc private func pick() {
        let items = inputView.string
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !items.isEmpty else {
            resultField.stringValue = "(no items)"
            return
        }
        let withoutRepl = withoutReplCheck.state == .on
        guard let picked = Generators.pickRandom(
            from: items,
            withoutReplacement: withoutRepl,
            alreadyPicked: alreadyPicked
        ) else {
            resultField.stringValue = "(all picked)"
            return
        }
        resultField.stringValue = picked
        pickedHistory.append(picked)
        if withoutRepl { alreadyPicked.insert(picked) }
        historyView.stringValue = "history: " + pickedHistory.suffix(10).reversed().joined(separator: " ← ")
    }

    @objc private func reset() {
        pickedHistory.removeAll()
        alreadyPicked.removeAll()
        resultField.stringValue = "—"
        historyView.stringValue = ""
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        return l
    }
}
