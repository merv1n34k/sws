import AppKit

final class ScratchpadView: NSView, NSTextViewDelegate {
    let textView: NSTextView
    private let scroll = NSScrollView()
    private let store = PersistentStore<String>(key: "scratchpad.md")
    private var saveDebounce: DispatchWorkItem?

    init() {
        textView = NSTextView()
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .white
        textView.backgroundColor = NSColor(white: 0.12, alpha: 1)
        textView.insertionPointColor = .white
        textView.drawsBackground = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.string = store.load("")
        textView.delegate = self

        // Match the existing text view configuration used elsewhere in
        // the app — sized to fill, scrollable, no border.
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        scroll.layer?.cornerRadius = 8
        scroll.layer?.masksToBounds = true

        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func textDidChange(_ notification: Notification) {
        saveDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.store.save(self.textView.string)
        }
        saveDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}
