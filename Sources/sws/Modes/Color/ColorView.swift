import AppKit

final class ColorView: NSView {
    private let mode: ColorMode
    private let pickButton = NSButton(title: "Pick Color", target: nil, action: nil)
    private let swatch = NSView()
    private let hexField = NSTextField(labelWithString: "—")
    private let rgbField = NSTextField(labelWithString: "—")
    private let hslField = NSTextField(labelWithString: "—")
    private let hsbField = NSTextField(labelWithString: "—")
    private let historyStrip = NSStackView()

    init(mode: ColorMode) {
        self.mode = mode
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        pickButton.target = self
        pickButton.action = #selector(pickTapped)
        pickButton.bezelStyle = .rounded
        pickButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pickButton)

        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        swatch.layer?.cornerRadius = 8
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        swatch.translatesAutoresizingMaskIntoConstraints = false
        addSubview(swatch)

        let hexRow = makeRow(label: "HEX", field: hexField, copyTag: 0)
        let rgbRow = makeRow(label: "RGB", field: rgbField, copyTag: 1)
        let hslRow = makeRow(label: "HSL", field: hslField, copyTag: 2)
        let hsbRow = makeRow(label: "HSB", field: hsbField, copyTag: 3)

        let formats = NSStackView(views: [hexRow, rgbRow, hslRow, hsbRow])
        formats.orientation = .vertical
        formats.alignment = .leading
        formats.spacing = 6
        formats.translatesAutoresizingMaskIntoConstraints = false
        addSubview(formats)

        historyStrip.orientation = .horizontal
        historyStrip.spacing = 6
        historyStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(historyStrip)

        NSLayoutConstraint.activate([
            pickButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            pickButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            swatch.topAnchor.constraint(equalTo: pickButton.bottomAnchor, constant: 10),
            swatch.centerXAnchor.constraint(equalTo: centerXAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 80),
            swatch.heightAnchor.constraint(equalToConstant: 40),

            formats.topAnchor.constraint(equalTo: swatch.bottomAnchor, constant: 14),
            formats.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            formats.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            historyStrip.topAnchor.constraint(greaterThanOrEqualTo: formats.bottomAnchor, constant: 12),
            historyStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            historyStrip.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            historyStrip.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func makeRow(label: String, field: NSTextField, copyTag: Int) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 36).isActive = true

        field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        field.textColor = .white
        field.isSelectable = true
        field.isEditable = false
        field.drawsBackground = false
        field.isBezeled = false
        field.lineBreakMode = .byTruncatingTail

        let copy = NSButton(title: "Copy", target: self, action: #selector(copyTapped(_:)))
        copy.bezelStyle = .inline
        copy.tag = copyTag
        copy.controlSize = .small

        let row = NSStackView(views: [labelView, field, copy])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    func refresh() {
        if let color = mode.current {
            swatch.layer?.backgroundColor = color.cgColor
            hexField.stringValue = ColorFormat.hex(color)
            rgbField.stringValue = ColorFormat.rgb(color)
            hslField.stringValue = ColorFormat.hsl(color)
            hsbField.stringValue = ColorFormat.hsb(color)
        } else {
            swatch.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
            hexField.stringValue = "—"
            rgbField.stringValue = "—"
            hslField.stringValue = "—"
            hsbField.stringValue = "—"
        }
        refreshHistory()
    }

    private func refreshHistory() {
        for sub in historyStrip.arrangedSubviews {
            historyStrip.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }
        for color in mode.history {
            let chip = ColorChip(color: color)
            chip.onClick = { [weak self] picked in self?.mode.apply(color: picked) }
            chip.widthAnchor.constraint(equalToConstant: 24).isActive = true
            chip.heightAnchor.constraint(equalToConstant: 24).isActive = true
            historyStrip.addArrangedSubview(chip)
        }
    }

    @objc private func pickTapped() {
        NSColorSampler().show { [weak self] color in
            guard let self = self, let color = color else { return }
            self.mode.apply(color: color)
        }
    }

    @objc private func copyTapped(_ sender: NSButton) {
        let value: String
        switch sender.tag {
        case 0: value = hexField.stringValue
        case 1: value = rgbField.stringValue
        case 2: value = hslField.stringValue
        case 3: value = hsbField.stringValue
        default: return
        }
        guard value != "—" else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
}

private final class ColorChip: NSView {
    var onClick: ((NSColor) -> Void)?
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        onClick?(color)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
