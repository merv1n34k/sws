import AppKit

/// A codec drives the two-pane converter view. Each codec decides
/// whether its right-side output is text or an image, and whether
/// edits in either pane flow both ways.
protocol EnDeCodec {
    var displayName: String { get }

    /// One-line description shown above the panes, telling the user
    /// what this codec does + a tiny usage hint.
    var hint: String { get }

    /// Pre-fill text for the left pane on codec switch (when the
    /// pane is empty) so the user has an example to riff on.
    var samplePlaceholder: String { get }

    /// True if the codec supports editing on the right side
    /// (i.e. bidirectional). False = right side is read-only output.
    var bidirectional: Bool { get }

    /// True if the right side renders an image rather than text.
    var rightIsImage: Bool { get }

    /// Convert text from left pane to right pane.
    /// For image codecs, return an empty string and the produced
    /// image via `imageFor(leftText:)` instead.
    func transformLeftToRight(_ left: String) -> String

    /// Convert text from right pane to left pane. Only called when
    /// `bidirectional == true`.
    func transformRightToLeft(_ right: String) -> String

    /// For image codecs (QR/Barcode write), produce an NSImage from
    /// the left text. Return nil if input is empty/invalid.
    func imageFor(leftText: String) -> NSImage?

    /// For image codecs that can also DECODE — given an image
    /// dropped on the right, return its decoded text on the left.
    /// Return nil if no scannable code is found.
    func textFrom(image: NSImage) -> String?
}

extension EnDeCodec {
    func imageFor(leftText: String) -> NSImage? { nil }
    func textFrom(image: NSImage) -> String? { nil }
    var samplePlaceholder: String { "" }
}
