import AppKit

/// Top: codec picker. Below: side-by-side left text pane + right
/// (text or image, depending on codec). For bidirectional text
/// codecs, editing either pane updates the other.
final class TwoPaneConverter: NSView, NSTextViewDelegate {
    private let codecs: [EnDeCodec]
    private let picker = NSPopUpButton()
    private let hintLabel = NSTextField(labelWithString: "")
    private let leftScroll: NSScrollView
    private let rightScroll: NSScrollView
    private let leftView: NSTextView
    private let rightView: NSTextView
    private let rightImage: CopyableDropImageView
    private let rightContainer = NSView()
    private var codec: EnDeCodec
    private var muted = false        // re-entrancy guard while we cross-update

    init(codecs: [EnDeCodec]) {
        precondition(!codecs.isEmpty)
        self.codecs = codecs
        self.codec = codecs[0]
        // NSTextView.scrollableTextView() returns a properly-wired
        // scroll view; reaching for documentView gives us the inner
        // text view. This is the recommended pattern (manual
        // scroll + text wiring tends to under-size on macOS).
        self.leftScroll = NSTextView.scrollableTextView()
        self.rightScroll = NSTextView.scrollableTextView()
        self.leftView = leftScroll.documentView as! NSTextView
        self.rightView = rightScroll.documentView as! NSTextView
        self.rightImage = CopyableDropImageView()

        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        for c in codecs { picker.addItem(withTitle: c.displayName) }
        picker.target = self
        picker.action = #selector(codecChanged)
        picker.bezelStyle = .rounded

        let typeLabel = NSTextField(labelWithString: "Type")
        typeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        typeLabel.textColor = .secondaryLabelColor

        let topRow = NSStackView(views: [typeLabel, picker])
        topRow.spacing = 8
        topRow.alignment = .centerY

        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 2
        hintLabel.lineBreakMode = .byWordWrapping

        configureTextView(leftView, scroll: leftScroll)
        configureTextView(rightView, scroll: rightScroll)
        leftView.delegate = self
        rightView.delegate = self

        rightImage.imageScaling = .scaleProportionallyUpOrDown
        rightImage.wantsLayer = true
        rightImage.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        rightImage.layer?.cornerRadius = 8
        rightImage.onImageDropped = { [weak self] image in
            self?.applyDroppedImage(image)
        }

        // Right pane is either scroll (text) or image — stack them in
        // a container and toggle isHidden.
        rightContainer.translatesAutoresizingMaskIntoConstraints = false
        rightScroll.translatesAutoresizingMaskIntoConstraints = false
        rightImage.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(rightScroll)
        rightContainer.addSubview(rightImage)
        NSLayoutConstraint.activate([
            rightScroll.topAnchor.constraint(equalTo: rightContainer.topAnchor),
            rightScroll.bottomAnchor.constraint(equalTo: rightContainer.bottomAnchor),
            rightScroll.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            rightScroll.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),
            rightImage.topAnchor.constraint(equalTo: rightContainer.topAnchor),
            rightImage.bottomAnchor.constraint(equalTo: rightContainer.bottomAnchor),
            rightImage.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            rightImage.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),
        ])

        leftScroll.translatesAutoresizingMaskIntoConstraints = false
        let split = NSStackView(views: [leftScroll, rightContainer])
        split.orientation = .horizontal
        split.distribution = .fillEqually
        split.spacing = 8
        split.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = NSStackView(views: [topRow, hintLabel, split])
        mainStack.orientation = .vertical
        mainStack.spacing = 6
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            hintLabel.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            split.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
        ])

        applyCodec()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func configureTextView(_ tv: NSTextView, scroll: NSScrollView) {
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = true
        tv.backgroundColor = NSColor(white: 0.12, alpha: 1)
        tv.textColor = .white
        tv.insertionPointColor = .white
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.textContainerInset = NSSize(width: 8, height: 8)

        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        scroll.layer?.masksToBounds = true
    }

    @objc private func codecChanged() {
        codec = codecs[picker.indexOfSelectedItem]
        applyCodec()
    }

    private func applyCodec() {
        hintLabel.stringValue = codec.hint
        rightView.isEditable = codec.bidirectional
        rightScroll.isHidden = codec.rightIsImage
        rightImage.isHidden = !codec.rightIsImage
        // Pre-fill the left pane with a sample if it's empty so the
        // user has something to riff on for tricky codecs (JWT, QR, …).
        if leftView.string.isEmpty && !codec.samplePlaceholder.isEmpty {
            muted = true
            leftView.string = codec.samplePlaceholder
            muted = false
        }
        runTransform(from: .left)
    }

    private enum Direction { case left, right }

    private func runTransform(from direction: Direction) {
        guard !muted else { return }
        muted = true
        defer { muted = false }
        switch direction {
        case .left:
            if codec.rightIsImage {
                rightImage.image = codec.imageFor(leftText: leftView.string)
            } else {
                rightView.string = codec.transformLeftToRight(leftView.string)
            }
        case .right:
            guard codec.bidirectional, !codec.rightIsImage else { return }
            leftView.string = codec.transformRightToLeft(rightView.string)
        }
    }

    private func applyDroppedImage(_ image: NSImage) {
        if let decoded = codec.textFrom(image: image) {
            muted = true
            leftView.string = decoded
            rightImage.image = image
            muted = false
        }
    }

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        if tv === leftView {
            runTransform(from: .left)
        } else if tv === rightView {
            runTransform(from: .right)
        }
    }
}

// MARK: - Drop-aware + click-to-copy image view

final class CopyableDropImageView: NSImageView {
    var onImageDropped: ((NSImage) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        if image != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let img = image else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([img])
        // Brief visual flash so the user knows it worked.
        let prevAlpha = alphaValue
        alphaValue = 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.alphaValue = prevAlpha
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

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
