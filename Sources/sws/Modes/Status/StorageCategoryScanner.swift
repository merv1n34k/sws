import AppKit

/// Walks a small set of well-known locations and sums file sizes so
/// the storage popover can render a Settings-style segmented bar of
/// categories.
///
/// Categories — these are the buckets the user asked for, not the
/// ones About this Mac shows:
///   - Applications  — /Applications
///   - Library       — /Library (root, system-installed support data)
///   - tmp           — /private/tmp
///   - Bin           — ~/.Trash
///   - Documents     — ~/Documents + ~/Downloads + ~/Desktop combined
///   - .dotfiles     — every hidden top-level entry under $HOME except .Trash
///   - Other data    — total used − sum of the categories above
///
/// Scans run on a utility-queue and cache for 60 s so reopening the
/// popover is instant. Some paths (e.g. /Library, /private/tmp) may
/// be partially walled off without Full Disk Access; the scanner
/// catches errors and continues, and the popover surfaces an FDA
/// banner when the kernel reports the grant is missing.
final class StorageCategoryScanner {
    static let shared = StorageCategoryScanner()

    struct Category {
        let id: String
        let label: String
        /// Color used for both the segmented bar region and the legend dot.
        let color: NSColor
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
    private let staleAfter: TimeInterval = 60

    /// Canonical order — segmented bar regions render in this order
    /// left-to-right.
    let categories: [Category] = [
        Category(id: "apps",      label: "Applications", color: .systemBlue),
        Category(id: "library",   label: "Library",      color: .systemPurple),
        Category(id: "tmp",       label: "tmp",          color: .systemOrange),
        Category(id: "trash",     label: "Bin",          color: .systemRed),
        Category(id: "documents", label: "Documents",    color: .systemGreen),
        Category(id: "dotfiles",  label: ".dotfiles",    color: .systemTeal),
        Category(id: "other",     label: "Other data",   color: .systemGray),
    ]

    /// Fires `completion` on the main queue. If a fresh cache exists,
    /// it's delivered synchronously (`isCached = true`) and no scan
    /// runs. If the cache is stale or empty, a scan is scheduled — the
    /// callback fires when results land. `usedBytes` is the volume's
    /// total used space, used to compute the "Other data" bucket.
    func results(usedBytes: Int64, _ completion: @escaping (_ results: [Result], _ isCached: Bool) -> Void) {
        if let when = lastScanAt, Date().timeIntervalSince(when) < staleAfter, !cached.isEmpty {
            completion(withOther(cached, usedBytes: usedBytes), true)
            return
        }
        if !cached.isEmpty {
            completion(withOther(cached, usedBytes: usedBytes), true)
        }
        pendingCompletions.append { [weak self] results in
            guard let self = self else { return }
            completion(self.withOther(results, usedBytes: usedBytes), false)
        }
        startScanIfNeeded()
    }

    func clearCache() {
        cached = []
        lastScanAt = nil
    }

    // MARK: - Scan

    private func startScanIfNeeded() {
        guard !inFlight else { return }
        inFlight = true
        queue.async { [weak self] in
            guard let self = self else { return }
            let results = self.scanAll()
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

    private func scanAll() -> [Result] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var out: [Result] = []

        out.append(Result(
            category: category(id: "apps")!,
            bytes: Self.folderSize(at: URL(fileURLWithPath: "/Applications"))
        ))
        out.append(Result(
            category: category(id: "library")!,
            bytes: Self.folderSize(at: URL(fileURLWithPath: "/Library"))
        ))
        out.append(Result(
            category: category(id: "tmp")!,
            bytes: Self.folderSize(at: URL(fileURLWithPath: "/private/tmp"))
        ))
        out.append(Result(
            category: category(id: "trash")!,
            bytes: Self.folderSize(at: home.appendingPathComponent(".Trash"))
        ))

        let documentsBytes =
            Self.folderSize(at: home.appendingPathComponent("Documents")) &+
            Self.folderSize(at: home.appendingPathComponent("Downloads")) &+
            Self.folderSize(at: home.appendingPathComponent("Desktop"))
        out.append(Result(category: category(id: "documents")!, bytes: documentsBytes))

        out.append(Result(category: category(id: "dotfiles")!, bytes: dotfilesBytes(home: home)))

        return out
    }

    /// Sum every top-level hidden entry under $HOME except .Trash
    /// (already its own bucket).
    private func dotfilesBytes(home: URL) -> Int64 {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return 0 }
        var total: Int64 = 0
        for child in children {
            let name = child.lastPathComponent
            guard name.hasPrefix(".") && name != ".Trash" else { continue }
            total &+= Self.folderSize(at: child)
        }
        return total
    }

    private func category(id: String) -> Category? {
        categories.first(where: { $0.id == id })
    }

    /// Appends the synthetic "other" category by subtracting known
    /// totals from the volume's used bytes. Floors at zero so an
    /// overshoot (e.g. partial-access misses) doesn't render as a
    /// negative segment.
    private func withOther(_ results: [Result], usedBytes: Int64) -> [Result] {
        let knownSum = results.reduce(Int64(0)) { $0 &+ $1.bytes }
        let other = max(0, usedBytes - knownSum)
        var out = results
        if let category = category(id: "other") {
            out.append(Result(category: category, bytes: other))
        }
        return out
    }

    // MARK: - Folder enumeration

    /// Sum of allocated bytes for every regular file under `url`.
    static func folderSize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
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
