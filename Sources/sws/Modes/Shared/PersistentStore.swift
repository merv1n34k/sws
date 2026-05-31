import Foundation

/// Thin Codable JSON-on-disk helper. Used by modes that need to
/// preserve state across launches (Clipboard, Scratchpad, Status
/// pinned widgets, etc.).
///
/// All files live under ~/.config/sws/<key>. The key may include
/// subdirectories ("clipboard.json", "status/pinned.json").
struct PersistentStore<Value: Codable> {
    let key: String

    private static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sws")
    }

    private var fileURL: URL {
        Self.configDir.appendingPathComponent(key)
    }

    /// Read the stored value, or `fallback` if missing/corrupt.
    func load(_ fallback: Value) -> Value {
        guard let data = try? Data(contentsOf: fileURL),
              let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return fallback
        }
        return value
    }

    /// Best-effort write. Logs and continues on failure.
    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("SWS PersistentStore[\(key)]: save failed: \(error)")
        }
    }

    /// Drops the on-disk file.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
