import AppKit

/// Top: codec picker. Below: left text pane and right pane (text or
/// image, depending on the codec). For bidirectional text codecs,
/// editing either pane updates the other. For image codecs, the
/// right pane shows the generated image and accepts dropped images
/// for decoding.
final class TwoPaneConverter: NSView, NSTextViewDelegate {
    private let codecs: [EnDeCodec]
    private let picker = NSPopUpButton()
    private let leftView = NSTextView()
    private let rightView = NSTextView()
    private let leftScroll = NSScrollView()
    private let rightScroll = NSScrollView()
    private let rightImage = DropImageView()
    private var codec: EnDeCodec
    private var muted = false        // re-entrancy guard while we cross-update

    init(codecs: [EnDeCodec]) {
        precondition(!codecs.isEmpty)
        self.codecs = codecs
        self.codec = codecs[0]
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        for c in codecs { picker.addItem(withTitle: c.displayName) }
        picker.target = self
        picker.action = #selector(codecChanged)
        picker.bezelStyle = .rounded
        picker.translatesAutoresizingMaskIntoConstraints = false

        let typeLabel = NSTextField(labelWithString: "Type")
        typeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        typeLabel.textColor = .secondaryLabelColor

        let topRow = NSStackView(views: [typeLabel, picker])
        topRow.spacing = 8
        topRow.alignment = .centerY
        topRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topRow)

        configureTextView(leftView, scroll: leftScroll)
        configureTextView(rightView, scroll: rightScroll)
        leftView.delegate = self
        rightView.delegate = self

        rightImage.translatesAutoresizingMaskIntoConstraints = false
        rightImage.imageScaling = .scaleProportionallyUpOrDown
        rightImage.wantsLayer = true
        rightImage.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        rightImage.layer?.cornerRadius = 8
        rightImage.onImageDropped = { [weak self] image in
            self?.applyDroppedImage(image)
        }

        addSubview(leftScroll)
        addSubview(rightScroll)
        addSubview(rightImage)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),

            leftScroll.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
            leftScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            leftScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),

            rightScroll.topAnchor.constraint(equalTo: leftScroll.topAnchor),
            rightScroll.bottomAnchor.constraint(equalTo: leftScroll.bottomAnchor),
            rightScroll.leadingAnchor.constraint(equalTo: leftScroll.trailingAnchor, constant: 8),
            rightScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rightScroll.widthAnchor.constraint(equalTo: leftScroll.widthAnchor),

            rightImage.topAnchor.constraint(equalTo: rightScroll.topAnchor),
            rightImage.bottomAnchor.constraint(equalTo: rightScroll.bottomAnchor),
            rightImage.leadingAnchor.constraint(equalTo: rightScroll.leadingAnchor),
            rightImage.trailingAnchor.constraint(equalTo: rightScroll.trailingAnchor),
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

        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        scroll.layer?.masksToBounds = true
    }

    @objc private func codecChanged() {
        codec = codecs[picker.indexOfSelectedItem]
        applyCodec()
    }

    private func applyCodec() {
        rightView.isEditable = codec.bidirectional
        rightScroll.isHidden = codec.rightIsImage
        rightImage.isHidden = !codec.rightIsImage
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
            rightImage.image = image  // show what they dropped
            muted = false
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        if tv === leftView {
            runTransform(from: .left)
        } else if tv === rightView {
            runTransform(from: .right)
        }
    }
}

// MARK: - Drop-aware image view

final class DropImageView: NSImageView {
    var onImageDropped: ((NSImage) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

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
