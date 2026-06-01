import AppKit

final class UUIDSection: NSView, GeneratorsSection {
    private let kindControl = NSSegmentedControl(
        labels: Generators.IDKind.allCases.map(\.rawValue),
        trackingMode: .selectOne, target: nil, action: nil
    )
    private let stepper = NSStepper()
    private let countLabel = NSTextField(labelWithString: "5")
    private let scroll: NSScrollView
    private let textView: ClickToCopyTextView
    private let regenButton = NSButton(title: "Regenerate", target: nil, action: nil)

    private var count: Int = 5
    private var kind: Generators.IDKind = .v4

    init() {
        let pair = ClickToCopyTextView.scrollable()
        scroll = pair.scroll
        textView = pair.view
        super.init(frame: .zero)
        buildLayout()
        wire()
        regenerate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        kindControl.segmentStyle = .texturedRounded
        kindControl.selectedSegment = 0

        stepper.minValue = 1
        stepper.maxValue = 100
        stepper.integerValue = count
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        countLabel.textColor = .white
        countLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let topRow = NSStackView(views: [
            kindControl,
            NSView(),
            label("Count"),
            stepper,
            countLabel,
        ])
        topRow.spacing = 8
        topRow.alignment = .centerY

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(white: 0.15, alpha: 1)
        textView.textColor = .white
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.toolTip = "Click to copy"

        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6
        scroll.layer?.masksToBounds = true

        regenButton.bezelStyle = .rounded

        let stack = NSStackView(views: [topRow, scroll, regenButton])
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
        kindControl.target = self
        kindControl.action = #selector(kindChanged)
        stepper.target = self
        stepper.action = #selector(countChanged)
        regenButton.target = self
        regenButton.action = #selector(regenerate)
    }

    func refresh() { regenerate() }

    @objc private func kindChanged() {
        kind = Generators.IDKind.allCases[kindControl.selectedSegment]
        regenerate()
    }

    @objc private func countChanged() {
        count = stepper.integerValue
        countLabel.stringValue = "\(count)"
        regenerate()
    }

    @objc private func regenerate() {
        let ids = Generators.generateIDs(kind: kind, count: count)
        textView.string = ids.joined(separator: "\n")
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        return l
    }
}
