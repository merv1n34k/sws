import AppKit

final class PasswordSection: NSView, GeneratorsSection {
    private var options = Generators.PasswordOptions()

    private let lengthSlider = NSSlider(value: 20, minValue: 4, maxValue: 64, target: nil, action: nil)
    private let lengthLabel = NSTextField(labelWithString: "20")
    private let lowerCheck = NSButton(checkboxWithTitle: "a-z", target: nil, action: nil)
    private let upperCheck = NSButton(checkboxWithTitle: "A-Z", target: nil, action: nil)
    private let digitCheck = NSButton(checkboxWithTitle: "0-9", target: nil, action: nil)
    private let symbolCheck = NSButton(checkboxWithTitle: "!@#$", target: nil, action: nil)
    private let output = ClickToCopyLabel()
    private let regenButton = NSButton(title: "Regenerate", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        buildLayout()
        wire()
        regenerate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        let lengthRow = NSStackView(views: [
            label("Length"),
            lengthSlider,
            lengthLabel,
        ])
        lengthRow.spacing = 8
        lengthRow.alignment = .centerY
        lengthLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lengthLabel.textColor = .white
        lengthLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let checkRow = NSStackView(views: [lowerCheck, upperCheck, digitCheck, symbolCheck])
        checkRow.spacing = 12
        checkRow.alignment = .centerY
        // NSButton checkbox titles render in the OS-default color and
        // ignore the window's appearance override in some configurations,
        // so spell out white explicitly via attributedTitle.
        for c in [lowerCheck, upperCheck, digitCheck, symbolCheck] {
            c.state = .on
            c.attributedTitle = NSAttributedString(
                string: c.title,
                attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.systemFont(ofSize: 12),
                ]
            )
        }

        output.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        output.textColor = .white
        output.maximumNumberOfLines = 2
        output.preferredMaxLayoutWidth = 380
        output.toolTip = "Click to copy"

        let outputBox = NSView()
        outputBox.wantsLayer = true
        outputBox.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        outputBox.layer?.cornerRadius = 6
        output.translatesAutoresizingMaskIntoConstraints = false
        outputBox.addSubview(output)
        NSLayoutConstraint.activate([
            output.topAnchor.constraint(equalTo: outputBox.topAnchor, constant: 8),
            output.bottomAnchor.constraint(equalTo: outputBox.bottomAnchor, constant: -8),
            output.leadingAnchor.constraint(equalTo: outputBox.leadingAnchor, constant: 10),
            output.trailingAnchor.constraint(equalTo: outputBox.trailingAnchor, constant: -10),
        ])

        regenButton.bezelStyle = .rounded

        let stack = NSStackView(views: [lengthRow, checkRow, outputBox, regenButton])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            lengthSlider.widthAnchor.constraint(equalToConstant: 220),
            outputBox.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func wire() {
        lengthSlider.target = self
        lengthSlider.action = #selector(lengthChanged)
        for c in [lowerCheck, upperCheck, digitCheck, symbolCheck] {
            c.target = self
            c.action = #selector(toggleChanged)
        }
        regenButton.target = self
        regenButton.action = #selector(regenerate)
    }

    func refresh() { regenerate() }

    @objc private func lengthChanged() {
        options.length = Int(lengthSlider.doubleValue.rounded())
        lengthLabel.stringValue = "\(options.length)"
        regenerate()
    }

    @objc private func toggleChanged() {
        options.lowercase = lowerCheck.state == .on
        options.uppercase = upperCheck.state == .on
        options.digits = digitCheck.state == .on
        options.symbols = symbolCheck.state == .on
        regenerate()
    }

    @objc private func regenerate() {
        let pw = Generators.password(options: options)
        output.stringValue = pw
        output.copyValue = pw
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        return l
    }
}
