import AppKit

final class ColorView: NSView {
    private let mode: ColorMode
    private let permissionBanner = PermissionBanner()
    private let hint = NSTextField(labelWithString: "click anywhere to pick · drag for a palette · click a value to copy")
    private let swatch = NSView()
    private let hexField = ClickToCopyLabel()
    private let rgbField = ClickToCopyLabel()
    private let hslField = ClickToCopyLabel()
    private let hsbField = ClickToCopyLabel()
    private let paletteStrip = PaletteStrip()
    private let contrastSection = ContrastSection()
    private let historyStrip = NSStackView()
    private let historyLabel = NSTextField(labelWithString: "Recent")

    init(mode: ColorMode) {
        self.mode = mode
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        permissionBanner.configure(
            title: "Screen Recording is off",
            body: "The color picker can only read the desktop wallpaper without it. Grant it in Settings → Privacy & Security → Screen Recording, then reopen sws.",
            settingsURL: SystemPermission.screenRecordingSettingsURL
        )
        permissionBanner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(permissionBanner)

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
        paletteStrip.onImageDropped = { [weak self] image in
            self?.extractPalette(from: image)
        }
        addSubview(paletteStrip)

        contrastSection.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contrastSection)

        let hexRow = makeRow(label: "HEX", field: hexField)
        let rgbRow = makeRow(label: "RGB", field: rgbField)
        let hslRow = makeRow(label: "HSL", field: hslField)
        let hsbRow = makeRow(label: "HSB", field: hsbField)

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
            permissionBanner.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            permissionBanner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            permissionBanner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            hint.topAnchor.constraint(equalTo: permissionBanner.bottomAnchor, constant: 6),
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

            contrastSection.topAnchor.constraint(equalTo: paletteStrip.bottomAnchor, constant: 10),
            contrastSection.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contrastSection.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            formats.topAnchor.constraint(equalTo: contrastSection.bottomAnchor, constant: 10),
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

    private func makeRow(label: String, field: ClickToCopyLabel) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 36).isActive = true

        field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        field.textColor = .white
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = "Click to copy"

        let row = NSStackView(views: [labelView, field])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    func refresh() {
        permissionBanner.setVisible(!SystemPermission.screenRecordingGranted())
        if let color = mode.current {
            swatch.layer?.backgroundColor = color.cgColor
            assignReadout(hexField, ColorFormat.hex(color))
            assignReadout(rgbField, ColorFormat.rgb(color))
            assignReadout(hslField, ColorFormat.hsl(color))
            assignReadout(hsbField, ColorFormat.hsb(color))
        } else {
            swatch.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
            assignReadout(hexField, "—")
            assignReadout(rgbField, "—")
            assignReadout(hslField, "—")
            assignReadout(hsbField, "—")
        }
        paletteStrip.colors = mode.palette
        refreshHistory()
    }

    private func assignReadout(_ field: ClickToCopyLabel, _ value: String) {
        field.stringValue = value
        field.copyValue = value == "—" ? "" : value
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

    private func extractPalette(from image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let palette = PaletteExtractor.extract(from: cg)
        if !palette.isEmpty {
            mode.apply(palette: palette)
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

}

// MARK: - Palette strip

final class PaletteStrip: NSView {
    var onClick: (() -> Void)?
    /// Image dropped by the user (file URL or pasteboard image).
    var onImageDropped: ((NSImage) -> Void)?
    var colors: [NSColor] = [] {
        didSet { needsDisplay = true }
    }

    private let placeholder = NSTextField(labelWithString: "drag on screen — or drop an image here — to extract a palette")
    private let copiedLabel = NSTextField(labelWithString: "copied")
    private var hideCopiedTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0.25, alpha: 1.0).cgColor
        registerForDraggedTypes([.fileURL, .png, .tiff])

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

    // MARK: - Drag-and-drop image

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor(white: 0.25, alpha: 1.0).cgColor
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        layer?.borderColor = NSColor(white: 0.25, alpha: 1.0).cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let img = NSImage(contentsOf: url) {
            onImageDropped?(img)
            return true
        }
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let img = images.first {
            onImageDropped?(img)
            return true
        }
        return false
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
