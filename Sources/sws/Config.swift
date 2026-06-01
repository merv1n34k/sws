import Foundation

struct ShortcutConfig: Codable, Equatable {
    var key: String
    var modifiers: [String]

    static let `default` = ShortcutConfig(key: "s", modifiers: ["shift", "option"])
}

/// One mode instance, as stored in config.json. The fields beyond the
/// core keys (id/type/hotkey) are kept as JSON and handed to the
/// factory in `ModeInstanceConfig.raw`.
struct ModeConfig {
    var id: String
    var type: String
    var hotkey: ShortcutConfig?
    /// Raw JSON of the entire mode entry (including id/type/hotkey)
    /// for factories that want to read their own fields.
    var raw: [String: Any]

    func toInstanceConfig() -> ModeInstanceConfig {
        ModeInstanceConfig(id: id, typeId: type, hotkey: hotkey, raw: raw)
    }
}

struct SWSConfig {
    var version: Int
    var defaultMode: String
    var modes: [ModeConfig]
    var width: Double
    var height: Double
    var rememberSize: Bool
    var fontFamily: String
    var fontSize: Double
    var logInput: Bool
    var clipboardMaxEntries: Int
    var clipboardMaxEntryBytes: Int

    static let currentVersion = 2

    static let `default` = SWSConfig(
        version: currentVersion,
        defaultMode: "calc",
        modes: [
            ModeConfig(id: "calc", type: "terminal", hotkey: shortcut("s"), raw: [
                "id": "calc", "type": "terminal",
                "hotkey": ["key": "s", "modifiers": ["shift", "option"]],
                "command": "/usr/bin/bc", "args": ["-l"],
            ]),
            ModeConfig(id: "color", type: "color", hotkey: shortcut("c"), raw: [
                "id": "color", "type": "color",
                "hotkey": ["key": "c", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "timer", type: "timer", hotkey: shortcut("q"), raw: [
                "id": "timer", "type": "timer",
                "hotkey": ["key": "q", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "status", type: "status", hotkey: shortcut("d"), raw: [
                "id": "status", "type": "status",
                "hotkey": ["key": "d", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "ende", type: "ende", hotkey: shortcut("e"), raw: [
                "id": "ende", "type": "ende",
                "hotkey": ["key": "e", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "generators", type: "generators", hotkey: shortcut("x"), raw: [
                "id": "generators", "type": "generators",
                "hotkey": ["key": "x", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "clipboard", type: "clipboard", hotkey: shortcut("a"), raw: [
                "id": "clipboard", "type": "clipboard",
                "hotkey": ["key": "a", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "ocr", type: "ocr", hotkey: shortcut("r"), raw: [
                "id": "ocr", "type": "ocr",
                "hotkey": ["key": "r", "modifiers": ["shift", "option"]],
            ]),
            ModeConfig(id: "scratchpad", type: "scratchpad", hotkey: shortcut("w"), raw: [
                "id": "scratchpad", "type": "scratchpad",
                "hotkey": ["key": "w", "modifiers": ["shift", "option"]],
            ]),
        ],
        width: 600,
        height: 400,
        rememberSize: true,
        fontFamily: "Menlo",
        fontSize: 14,
        logInput: false,
        clipboardMaxEntries: 500,
        clipboardMaxEntryBytes: 1_000_000
    )

    private static func shortcut(_ key: String) -> ShortcutConfig {
        ShortcutConfig(key: key, modifiers: ["shift", "option"])
    }

    static var logFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".sws.log")
    }

    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sws")
    }

    static var configFile: URL {
        configDir.appendingPathComponent("config.json")
    }

    static func load() -> SWSConfig {
        let fm = FileManager.default
        let file = configFile

        if fm.fileExists(atPath: file.path) {
            do {
                let data = try Data(contentsOf: file)
                let (config, migrated) = try parse(data: data)
                if migrated {
                    config.save()
                    NSLog("SWS: migrated config to v\(SWSConfig.currentVersion)")
                }
                return config
            } catch {
                NSLog("SWS: failed to load config: \(error). Using defaults.")
                return .default
            }
        }

        let config = SWSConfig.default
        config.save()
        return config
    }

    /// Parses raw JSON, transparently migrating older schemas to v2.
    /// Returns the parsed config and a flag indicating whether a migration ran.
    static func parse(data: Data) throws -> (SWSConfig, migrated: Bool) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "SWSConfig", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "config root is not an object"])
        }

        if json["modes"] != nil {
            return (try decodeV2(json), migrated: false)
        }
        if let tools = json["tools"] as? [[String: Any]], !tools.isEmpty {
            return (try decodeV2(migrateToolsToV2(json, tools: tools)), migrated: true)
        }
        return (try decodeV2(migrateV1ToV2(json)), migrated: true)
    }

    private static func decodeV2(_ json: [String: Any]) throws -> SWSConfig {
        guard let modesAny = json["modes"] as? [[String: Any]] else {
            throw NSError(domain: "SWSConfig", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "missing 'modes' array"])
        }
        let modes: [ModeConfig] = try modesAny.map { dict in
            guard let id = dict["id"] as? String else {
                throw NSError(domain: "SWSConfig", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "mode missing 'id'"])
            }
            guard let type = dict["type"] as? String else {
                throw NSError(domain: "SWSConfig", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "mode '\(id)' missing 'type'"])
            }
            return ModeConfig(
                id: id,
                type: type,
                hotkey: decodeShortcut(dict["hotkey"]),
                raw: dict
            )
        }

        let defaultMode = (json["defaultMode"] as? String) ?? modes.first?.id ?? "default"

        return SWSConfig(
            version: (json["version"] as? Int) ?? currentVersion,
            defaultMode: defaultMode,
            modes: modes,
            width: (json["width"] as? Double) ?? 600,
            height: (json["height"] as? Double) ?? 400,
            rememberSize: (json["rememberSize"] as? Bool) ?? true,
            fontFamily: (json["fontFamily"] as? String) ?? "Menlo",
            fontSize: (json["fontSize"] as? Double) ?? 14,
            logInput: (json["logInput"] as? Bool) ?? false,
            clipboardMaxEntries: (json["clipboardMaxEntries"] as? Int) ?? 500,
            clipboardMaxEntryBytes: (json["clipboardMaxEntryBytes"] as? Int) ?? 1_000_000
        )
    }

    /// Migrates a `tools`-style config (intermediate schema with a top-level
    /// `tools: [{name, type, command, args, key}]` array and shared
    /// top-level `shortcut` + `modifiers`) into v2.
    ///
    /// The first tool becomes the default mode and inherits the top-level
    /// `shortcut` as its summon hotkey. Subsequent tools get hotkeys
    /// composed of `tool.key` + the top-level `modifiers`.
    static func migrateToolsToV2(_ v1: [String: Any], tools: [[String: Any]]) -> [String: Any] {
        let sharedModifiers = (v1["modifiers"] as? [String]) ?? ["shift", "option"]
        let summonShortcut = v1["shortcut"] as? [String: Any]

        var modes: [[String: Any]] = []
        for (idx, tool) in tools.enumerated() {
            let id = (tool["name"] as? String) ?? "tool\(idx)"
            let type = (tool["type"] as? String) ?? "terminal"
            let command = tool["command"] as? String ?? ""
            let args = (tool["args"] as? [String]) ?? []

            let hotkey: [String: Any]
            if idx == 0, let summon = summonShortcut {
                hotkey = summon
            } else {
                let key = (tool["key"] as? String) ?? "s"
                hotkey = ["key": key, "modifiers": sharedModifiers]
            }

            modes.append([
                "id": id,
                "type": type,
                "hotkey": hotkey,
                "command": command,
                "args": args,
            ])
        }

        var v2: [String: Any] = [
            "version": currentVersion,
            "defaultMode": modes.first?["id"] ?? "default",
            "modes": modes,
        ]
        for key in ["width", "height", "rememberSize", "fontFamily", "fontSize", "logInput"] {
            if let v = v1[key] { v2[key] = v }
        }
        return v2
    }

    /// Wraps a v1 config (top-level `command`/`args`/`shortcut`) into a
    /// single `default` terminal mode.
    static func migrateV1ToV2(_ v1: [String: Any]) -> [String: Any] {
        let shortcut = v1["shortcut"] as? [String: Any]
            ?? ["key": "s", "modifiers": ["shift", "option"]]
        let command = v1["command"] as? String ?? "/usr/bin/bc"
        let args = v1["args"] as? [String] ?? ["-l"]

        let mode: [String: Any] = [
            "id": "default",
            "type": "terminal",
            "hotkey": shortcut,
            "command": command,
            "args": args,
        ]

        var v2: [String: Any] = [
            "version": currentVersion,
            "defaultMode": "default",
            "modes": [mode],
        ]
        for key in ["width", "height", "rememberSize", "fontFamily", "fontSize", "logInput"] {
            if let v = v1[key] { v2[key] = v }
        }
        return v2
    }

    private static func decodeShortcut(_ any: Any?) -> ShortcutConfig? {
        guard let dict = any as? [String: Any],
              let key = dict["key"] as? String,
              let mods = dict["modifiers"] as? [String] else {
            return nil
        }
        return ShortcutConfig(key: key, modifiers: mods)
    }

    func save() {
        let fm = FileManager.default
        let dir = SWSConfig.configDir

        do {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let json = toJSON()
            let data = try JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: SWSConfig.configFile)
        } catch {
            NSLog("SWS: failed to save config: \(error)")
        }
    }

    func toJSON() -> [String: Any] {
        return [
            "version": version,
            "defaultMode": defaultMode,
            "modes": modes.map { $0.raw },
            "width": width,
            "height": height,
            "rememberSize": rememberSize,
            "fontFamily": fontFamily,
            "fontSize": fontSize,
            "logInput": logInput,
            "clipboardMaxEntries": clipboardMaxEntries,
            "clipboardMaxEntryBytes": clipboardMaxEntryBytes,
        ]
    }

    func withSize(width: Double, height: Double) -> SWSConfig {
        var copy = self
        copy.width = width
        copy.height = height
        return copy
    }

    func mode(byID id: String) -> ModeConfig? {
        modes.first(where: { $0.id == id })
    }
}
