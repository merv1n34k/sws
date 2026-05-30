import AppKit

final class ColorView: NSView {
    private let mode: ColorMode
    private let hint = NSTextField(labelWithString: "click anywhere to pick · drag for a palette")
    private let swatch = NSView()
    private let hexField = NSTextField(labelWithString: "—")
    private let rgbField = NSTextField(labelWithString: "—")
    private let hslField = NSTextField(labelWithString: "—")
    private let hsbField = NSTextField(labelWithString: "—")
    private let paletteStrip = PaletteStrip()
    private let historyStrip = NSStackView()
    private let historyLabel = NSTextField(labelWithString: "Recent")

    init(mode: ColorMode) {
        self.mode = mode
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)

        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        swatch.layer?.cornerRadius = 8
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        swatch.translatesAutoresizingMaskIntoConstraints = false
        addSubview(swatch)

        paletteStrip.translatesAutoresizingMaskIntoConstraints = false
        paletteStrip.onClick = { [weak self] in self?.copyPaletteCSV() }
        addSubview(paletteStrip)

        let hexRow = makeRow(label: "HEX", field: hexField, copyTag: 0)
        let rgbRow = makeRow(label: "RGB", field: rgbField, copyTag: 1)
        let hslRow = makeRow(label: "HSL", field: hslField, copyTag: 2)
        let hsbRow = makeRow(label: "HSB", field: hsbField, copyTag: 3)

        let formats = NSStackView(views: [hexRow, rgbRow, hslRow, hsbRow])
        formats.orientation = .vertical
        formats.alignment = .leading
        formats.spacing = 4
        formats.translatesAutoresizingMaskIntoConstraints = false
        addSubview(formats)

        historyLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        historyLabel.textColor = .secondaryLabelColor
        historyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(historyLabel)

        historyStrip.orientation = .horizontal
        historyStrip.spacing = 6
        historyStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(historyStrip)

        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            hint.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            swatch.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            swatch.centerXAnchor.constraint(equalTo: centerXAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 70),
            swatch.heightAnchor.constraint(equalToConstant: 32),

            paletteStrip.topAnchor.constraint(equalTo: swatch.bottomAnchor, constant: 10),
            paletteStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            paletteStrip.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            paletteStrip.heightAnchor.constraint(equalToConstant: 28),

            formats.topAnchor.constraint(equalTo: paletteStrip.bottomAnchor, constant: 10),
            formats.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            formats.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            historyLabel.topAnchor.constraint(greaterThanOrEqualTo: formats.bottomAnchor, constant: 12),
            historyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            historyStrip.topAnchor.constraint(equalTo: historyLabel.bottomAnchor, constant: 4),
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
        paletteStrip.colors = mode.palette
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
            chip.widthAnchor.constraint(equalToConstant: 22).isActive = true
            chip.heightAnchor.constraint(equalToConstant: 22).isActive = true
            historyStrip.addArrangedSubview(chip)
        }
    }

    private func copyPaletteCSV() {
        let csv = mode.paletteCSV()
        guard !csv.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(csv, forType: .string)
        paletteStrip.flashCopied()
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

// MARK: - Palette strip

final class PaletteStrip: NSView {
    var onClick: (() -> Void)?
    var colors: [NSColor] = [] {
        didSet { needsDisplay = true }
    }

    private let placeholder = NSTextField(labelWithString: "drag on screen to extract a palette")
    private let copiedLabel = NSTextField(labelWithString: "copied")
    private var hideCopiedTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0.25, alpha: 1.0).cgColor

        placeholder.font = NSFont.systemFont(ofSize: 10)
        placeholder.textColor = .secondaryLabelColor
        placeholder.alignment = .center
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        copiedLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        copiedLabel.textColor = .white
        copiedLabel.alignment = .center
        copiedLabel.isHidden = true
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(copiedLabel)
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if colors.isEmpty { return }
        let cellWidth = bounds.width / CGFloat(colors.count)
        for (i, color) in colors.enumerated() {
            let rect = NSRect(
                x: CGFloat(i) * cellWidth,
                y: 0,
                width: cellWidth,
                height: bounds.height
            )
            color.setFill()
            rect.fill()
        }
    }

    override func layout() {
        super.layout()
        placeholder.isHidden = !colors.isEmpty
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard !colors.isEmpty else { return }
        onClick?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: colors.isEmpty ? .arrow : .pointingHand)
    }

    func flashCopied() {
        copiedLabel.stringValue = "copied!"
        copiedLabel.isHidden = false
        hideCopiedTimer?.invalidate()
        hideCopiedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.copiedLabel.isHidden = true
        }
    }
}

// MARK: - Small history chip

final class ColorChip: NSView {
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
