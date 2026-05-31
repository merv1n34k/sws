import AppKit

final class LoremSection: NSView, GeneratorsSection {
    private let unitControl = NSSegmentedControl(
        labels: Generators.LoremUnit.allCases.map(\.rawValue.capitalized),
        trackingMode: .selectOne, target: nil, action: nil
    )
    private let stepper = NSStepper()
    private let countLabel = NSTextField(labelWithString: "3")
    private let scroll: NSScrollView
    private let textView: NSTextView
    private let regenButton = NSButton(title: "Regenerate", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)

    private var unit: Generators.LoremUnit = .sentences
    private var count: Int = 3

    init() {
        // scrollableTextView() sizes the inner NSTextView properly
        // (wrap-to-container width, vertical resize, etc.) — bare
        // NSTextView() + scroll.documentView = … doesn't.
        scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView
        super.init(frame: .zero)
        buildLayout()
        wire()
        unitControl.selectedSegment = 1  // sentences as default
        regenerate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        unitControl.segmentStyle = .texturedRounded

        stepper.minValue = 1
        stepper.maxValue = 50
        stepper.integerValue = count
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        countLabel.textColor = .white
        countLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let topRow = NSStackView(views: [
            unitControl, NSView(), label("Count"), stepper, countLabel,
        ])
        topRow.spacing = 8
        topRow.alignment = .centerY

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(white: 0.15, alpha: 1)
        textView.textColor = .white
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6
        scroll.layer?.masksToBounds = true

        let buttonRow = NSStackView(views: [regenButton, copyButton])
        buttonRow.spacing = 8
        regenButton.bezelStyle = .rounded
        copyButton.bezelStyle = .rounded

        let stack = NSStackView(views: [topRow, scroll, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            topRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func wire() {
        unitControl.target = self
        unitControl.action = #selector(unitChanged)
        stepper.target = self
        stepper.action = #selector(countChanged)
        regenButton.target = self
        regenButton.action = #selector(regenerate)
        copyButton.target = self
        copyButton.action = #selector(copyOutput)
    }

    func refresh() { regenerate() }

    @objc private func unitChanged() {
        unit = Generators.LoremUnit.allCases[unitControl.selectedSegment]
        regenerate()
    }

    @objc private func countChanged() {
        count = stepper.integerValue
        countLabel.stringValue = "\(count)"
        regenerate()
    }

    @objc private func regenerate() {
        textView.string = Generators.lorem(unit: unit, count: count)
    }

    @objc private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textView.string, forType: .string)
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        return l
    }
}
