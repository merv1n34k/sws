import AppKit

/// Watches NSPasteboard.general for new entries, applies the size cap,
/// and notifies listeners. Persists to ~/.config/sws/clipboard.json
/// (and ~/.config/sws/clipboard-images/<uuid>.png for image entries).
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()
    static let didChangeNotification = Notification.Name("sws.clipboard.didChange")

    /// Per-entry cap. Text over this is truncated; images over this
    /// are dropped (only metadata kept).
    private let perEntryCap = 1_000_000   // 1 MB
    /// Maximum number of entries to keep.
    private let maxEntries = 50
    private let pollInterval: TimeInterval = 0.5

    private let store = PersistentStore<ClipboardHistory>(key: "clipboard.json")
    private(set) var history: ClipboardHistory
    private var timer: Timer?

    private static var imagesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sws/clipboard-images")
    }

    private init() {
        self.history = store.load(ClipboardHistory())
    }

    func start() {
        guard timer == nil else { return }
        // Seed lastChangeCount so we don't re-ingest whatever is on
        // the pasteboard when sws launches.
        if history.lastChangeCount == 0 {
            history.lastChangeCount = NSPasteboard.general.changeCount
        }
        let t = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Manually erase a single entry by id.
    func remove(id: String) {
        if let entry = history.entries.first(where: { $0.id == id }),
           let path = entry.imagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        history.entries.removeAll { $0.id == id }
        store.save(history)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Wipe all history (and image files on disk).
    func clearAll() {
        for entry in history.entries {
            if let path = entry.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        history.entries.removeAll()
        store.save(history)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Put a stored entry back onto the pasteboard so the user can paste it.
    func putBack(id: String) {
        guard let entry = history.entries.first(where: { $0.id == id }) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        switch entry.kind {
        case .text, .textTruncated:
            if let body = entry.textBody {
                pb.setString(body, forType: .string)
            }
        case .image:
            if let path = entry.imagePath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let img = NSImage(data: data) {
                pb.writeObjects([img])
            }
        case .imageTooLarge:
            break
        }
        // Update lastChangeCount so we don't re-ingest our own put-back.
        history.lastChangeCount = pb.changeCount
        store.save(history)
    }

    // MARK: - Polling

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != history.lastChangeCount else { return }
        history.lastChangeCount = pb.changeCount

        if let text = pb.string(forType: .string), !text.isEmpty {
            ingestText(text)
        } else if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
                  let img = images.first {
            ingestImage(img)
        }
        store.save(history)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func ingestText(_ text: String) {
        let bytes = text.utf8.count
        let entry: ClipboardEntry
        if bytes > perEntryCap {
            // Truncate at the cap boundary (UTF-8 byte-safe).
            let truncated = String(text.utf8.prefix(perEntryCap)) ?? String(text.prefix(perEntryCap / 4))
            entry = ClipboardEntry(
                id: UUID().uuidString,
                kind: .textTruncated,
                createdAt: Date(),
                preview: previewLine(of: text),
                textBody: truncated,
                imagePath: nil,
                bytes: bytes,
                width: nil, height: nil
            )
        } else {
            entry = ClipboardEntry(
                id: UUID().uuidString,
                kind: .text,
                createdAt: Date(),
                preview: previewLine(of: text),
                textBody: text,
                imagePath: nil,
                bytes: bytes,
                width: nil, height: nil
            )
        }
        prepend(entry)
    }

    private func ingestImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let bytes = png.count
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        if bytes > perEntryCap {
            // Skip image; keep placeholder.
            let entry = ClipboardEntry(
                id: UUID().uuidString,
                kind: .imageTooLarge,
                createdAt: Date(),
                preview: "image \(w)×\(h), \(humanBytes(bytes)) (too large to keep)",
                textBody: nil,
                imagePath: nil,
                bytes: bytes,
                width: w, height: h
            )
            prepend(entry)
            return
        }
        // Save image to disk.
        try? FileManager.default.createDirectory(
            at: Self.imagesDir, withIntermediateDirectories: true
        )
        let imageID = UUID().uuidString
        let url = Self.imagesDir.appendingPathComponent("\(imageID).png")
        try? png.write(to: url)
        let entry = ClipboardEntry(
            id: imageID,
            kind: .image,
            createdAt: Date(),
            preview: "image \(w)×\(h), \(humanBytes(bytes))",
            textBody: nil,
            imagePath: url.path,
            bytes: bytes,
            width: w, height: h
        )
        prepend(entry)
    }

    private func prepend(_ entry: ClipboardEntry) {
        history.entries.insert(entry, at: 0)
        if history.entries.count > maxEntries {
            let dropping = history.entries.suffix(history.entries.count - maxEntries)
            for d in dropping {
                if let path = d.imagePath {
                    try? FileManager.default.removeItem(atPath: path)
                }
            }
            history.entries.removeLast(history.entries.count - maxEntries)
        }
    }

    private func previewLine(of text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.count > 200 ? String(firstLine.prefix(200)) + "…" : firstLine
    }

    private func humanBytes(_ n: Int) -> String {
        let kb = Double(n) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}
