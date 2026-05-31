import Foundation

/// One entry in the clipboard history. Either text or an image (the
/// image's bytes are stored on disk; this struct holds the metadata
/// + thumbnail path).
struct ClipboardEntry: Codable, Identifiable {
    enum Kind: String, Codable {
        case text
        case image
        case textTruncated   // long text trimmed to 1 MB
        case imageTooLarge   // image was over the cap; only metadata kept
    }

    let id: String
    let kind: Kind
    let createdAt: Date
    let preview: String         // single-line summary for the list
    let textBody: String?       // full text for .text / .textTruncated
    let imagePath: String?      // absolute path under clipboard-images/ for .image
    let bytes: Int              // original byte size (informational)
    let width: Int?             // image width if kind == .image
    let height: Int?
}

struct ClipboardHistory: Codable {
    var entries: [ClipboardEntry] = []
    /// Highest pasteboard changeCount we've already ingested. Lets us
    /// resume polling after launch without grabbing a stale entry.
    var lastChangeCount: Int = 0
}
