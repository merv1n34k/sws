import AppKit
import UniformTypeIdentifiers

final class OCRView: NSView {
    private let dropZone = OCRDropZone()
    private let browseButton = NSButton(title: "Browse…", target: nil, action: nil)
    private let langPicker = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let outputScroll = NSScrollView()
    private let outputView = ClickToCopyTextView()
    private var lastAutoLoadedChangeCount: Int = -1

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        buildLayout()
        wire()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.onDrop = { [weak self] source in self?.process(source: source) }
        addSubview(dropZone)

        browseButton.bezelStyle = .rounded

        langPicker.bezelStyle = .rounded
        langPicker.addItem(withTitle: "Auto")
        for lang in OCRPipeline.supportedLanguages {
            langPicker.addItem(withTitle: lang)
        }

        let actions = NSStackView(views: [browseButton, NSView(), label("Language"), langPicker])
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.alignment = .centerY

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        outputView.isEditable = false
        outputView.isSelectable = true
        outputView.drawsBackground = true
        outputView.backgroundColor = NSColor(white: 0.12, alpha: 1)
        outputView.textColor = .white
        outputView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        outputView.textContainerInset = NSSize(width: 8, height: 8)

        outputScroll.documentView = outputView
        outputScroll.hasVerticalScroller = true
        outputScroll.borderType = .noBorder
        outputScroll.wantsLayer = true
        outputScroll.layer?.cornerRadius = 8
        outputScroll.layer?.masksToBounds = true
        outputScroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [dropZone, actions, statusLabel, outputScroll])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            dropZone.heightAnchor.constraint(equalToConstant: 90),
            dropZone.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }

    private func wire() {
        browseButton.target = self
        browseButton.action = #selector(browseForFile)
    }

    /// Called when the OCR mode's window becomes visible. If the
    /// pasteboard holds an image, run it through the pipeline without
    /// the user having to click anything.
    func autoLoadFromPasteboardIfAvailable() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastAutoLoadedChangeCount else { return }
        guard let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let img = images.first else { return }
        lastAutoLoadedChangeCount = pb.changeCount
        process(source: .image(img))
    }

    @objc private func browseForFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .pdf]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            if url.pathExtension.lowercased() == "pdf" {
                self?.process(source: .pdf(url))
            } else if let img = NSImage(contentsOf: url) {
                self?.process(source: .image(img))
            }
        }
    }

    private func process(source: OCRPipeline.Source) {
        statusLabel.stringValue = "Recognizing…"
        outputView.string = ""
        let lang = langPicker.indexOfSelectedItem == 0 ? nil : langPicker.titleOfSelectedItem
        OCRPipeline.recognize(source: source, language: lang) { [weak self] result in
            guard let self = self else { return }
            if let result = result {
                self.outputView.string = result.joined
                let pageWord = result.pages.count == 1 ? "page" : "pages"
                self.statusLabel.stringValue = "\(result.pages.count) \(pageWord), \(result.joined.count) chars — click text to copy all."
            } else {
                self.statusLabel.stringValue = "Failed to read."
            }
        }
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        return l
    }
}

// MARK: - Drop zone

final class OCRDropZone: NSView {
    var onDrop: ((OCRPipeline.Source) -> Void)?
    private let label = NSTextField(labelWithString: "Drop image or PDF here  ·  ⌥⇧A then ⌥⇧R to OCR clipboard")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0.3, alpha: 1).cgColor
        layer?.backgroundColor = NSColor(white: 0.13, alpha: 1).cgColor
        registerForDraggedTypes([.fileURL, .png, .tiff])

        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.systemBlue.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor(white: 0.3, alpha: 1).cgColor
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        layer?.borderColor = NSColor(white: 0.3, alpha: 1).cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            if url.pathExtension.lowercased() == "pdf" {
                onDrop?(.pdf(url))
                return true
            }
            if let img = NSImage(contentsOf: url) {
                onDrop?(.image(img))
                return true
            }
        }
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let img = images.first {
            onDrop?(.image(img))
            return true
        }
        return false
    }
}
