import Foundation

/// Walks the user's well-known top-level folders and sums the bytes in
/// each. Runs entirely on a background queue and caches results for a
/// minute so the popover can open instantly on repeat openings.
///
/// Apple's About this Mac → Storage uses a private scan that needs
/// Full Disk Access and looks at content categories the kernel
/// indexes. We can't access that without FDA, so we approximate by
/// summing the sizes of the standard user folders — Documents,
/// Downloads, Pictures, etc. — which is what most users actually want
/// to see anyway.
final class StorageCategoryScanner {
    static let shared = StorageCategoryScanner()

    struct Category {
        let id: String
        let label: String
        let symbol: String  // SF Symbol
        let url: URL
    }

    struct Result {
        let category: Category
        let bytes: Int64
    }

    private let queue = DispatchQueue(label: "sws.storage.scan", qos: .utility)
    private var cached: [Result] = []
    private var lastScanAt: Date?
    private var inFlight = false
    private var pendingCompletions: [([Result]) -> Void] = []
    /// Re-scan window — we don't recompute folder sizes faster than
    /// this. Folder enumeration is expensive for /Applications and
    /// ~/Library, so cache aggressively.
    private let staleAfter: TimeInterval = 60

    /// The canonical category list, in the order they should appear.
    /// Bin (Trash) is intentionally first per the user's "bin, docs,
    /// images" framing — surface the actively-reclaimable space at
    /// the top.
    let categories: [Category] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Category(id: "trash", label: "Bin", symbol: "trash",
                     url: home.appendingPathComponent(".Trash")),
            Category(id: "documents", label: "Documents", symbol: "doc.text",
                     url: home.appendingPathComponent("Documents")),
            Category(id: "downloads", label: "Downloads", symbol: "arrow.down.circle",
                     url: home.appendingPathComponent("Downloads")),
            Category(id: "desktop", label: "Desktop", symbol: "menubar.dock.rectangle",
                     url: home.appendingPathComponent("Desktop")),
            Category(id: "pictures", label: "Pictures", symbol: "photo.on.rectangle",
                     url: home.appendingPathComponent("Pictures")),
            Category(id: "music", label: "Music", symbol: "music.note",
                     url: home.appendingPathComponent("Music")),
            Category(id: "movies", label: "Movies", symbol: "film",
                     url: home.appendingPathComponent("Movies")),
            Category(id: "apps", label: "Applications", symbol: "app.gift",
                     url: URL(fileURLWithPath: "/Applications")),
        ]
    }()

    /// Returns cached results if fresh, otherwise schedules a scan and
    /// fires `completion` on the main queue when it finishes. The
    /// `isCached` flag tells callers whether the values are stale (i.e.
    /// a fresh scan is now running and a follow-up callback is coming).
    func results(_ completion: @escaping (_ results: [Result], _ isCached: Bool) -> Void) {
        if let when = lastScanAt, Date().timeIntervalSince(when) < staleAfter, !cached.isEmpty {
            completion(cached, true)
            return
        }
        // Hand back any prior cache immediately so the UI isn't empty
        // while the scan runs.
        if !cached.isEmpty {
            completion(cached, true)
        }
        pendingCompletions.append { results in completion(results, false) }
        startScanIfNeeded()
    }

    func clearCache() {
        cached = []
        lastScanAt = nil
    }

    private func startScanIfNeeded() {
        guard !inFlight else { return }
        inFlight = true
        let categoriesSnapshot = categories
        queue.async { [weak self] in
            guard let self = self else { return }
            let results = categoriesSnapshot.map { category in
                Result(category: category, bytes: Self.folderSize(at: category.url))
            }
            DispatchQueue.main.async {
                self.cached = results
                self.lastScanAt = Date()
                self.inFlight = false
                let callbacks = self.pendingCompletions
                self.pendingCompletions.removeAll()
                for cb in callbacks { cb(results) }
            }
        }
    }

    /// Sum of allocated bytes for every regular file under `url`.
    /// Uses `totalFileAllocatedSize` so symlinks and zero-byte files
    /// don't inflate the total, and the system's compression accounting
    /// is honored.
    static func folderSize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .isRegularFileKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize else { continue }
            total &+= Int64(size)
        }
        return total
    }
}
