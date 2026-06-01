import AppKit

/// In sws everything readable is click-to-copy. These two helpers
/// avoid the per-mode "Copy" buttons by attaching copy-on-click to the
/// value itself.

/// Plain text label. `copyValue` is what lands on the pasteboard when
/// the user clicks it (may differ from the displayed `stringValue` —
/// e.g. show "local 10.0.0.1 · public 1.2.3.4" but copy only the
/// public IP). Set to empty string to disable.
final class ClickToCopyLabel: NSTextField {
    var copyValue: String = ""

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        if !copyValue.isEmpty {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !copyValue.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(copyValue, forType: .string)
        flash()
    }

    private func flash() {
        let prev = textColor
        textColor = .systemBlue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.textColor = prev
        }
    }
}

/// NSTextView subclass that copies its entire contents to the
/// pasteboard on plain click (no drag-select). Drag-selecting still
/// works as normal — we only copy-all when there's no selection after
/// the click.
final class ClickToCopyTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if selectedRange().length == 0, !string.isEmpty {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(string, forType: .string)
            flash()
        }
    }

    private func flash() {
        let prev = backgroundColor
        backgroundColor = NSColor.systemBlue.withAlphaComponent(0.25)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.backgroundColor = prev
        }
    }

    /// Returns an NSScrollView wired up to host a ClickToCopyTextView —
    /// the same shape as `NSTextView.scrollableTextView()` but with a
    /// subclass that copies on click.
    static func scrollable() -> (scroll: NSScrollView, view: ClickToCopyTextView) {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder

        let contentSize = scroll.contentSize
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let view = ClickToCopyTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: container)
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true

        scroll.documentView = view
        return (scroll, view)
    }
}
