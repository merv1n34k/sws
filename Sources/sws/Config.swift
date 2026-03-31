import Foundation

struct ShortcutConfig: Codable {
    var key: String
    var modifiers: [String]

    static let `default` = ShortcutConfig(key: "s", modifiers: ["shift", "option"])
}

struct SWSConfig: Codable {
    var shortcut: ShortcutConfig
    var command: String
    var args: [String]
    var width: Double
    var height: Double
    var rememberSize: Bool
    var fontFamily: String
    var fontSize: Double
    var logInput: Bool

    static let `default` = SWSConfig(
        shortcut: .default,
        command: "/usr/bin/bc",
        args: ["-l"],
        width: 600,
        height: 400,
        rememberSize: true,
        fontFamily: "Menlo",
        fontSize: 14,
        logInput: false
    )

    init(shortcut: ShortcutConfig, command: String, args: [String],
         width: Double, height: Double, rememberSize: Bool,
         fontFamily: String, fontSize: Double, logInput: Bool) {
        self.shortcut = shortcut
        self.command = command
        self.args = args
        self.width = width
        self.height = height
        self.rememberSize = rememberSize
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.logInput = logInput
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shortcut = try c.decode(ShortcutConfig.self, forKey: .shortcut)
        command = try c.decode(String.self, forKey: .command)
        args = try c.decode([String].self, forKey: .args)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
        rememberSize = try c.decode(Bool.self, forKey: .rememberSize)
        fontFamily = try c.decode(String.self, forKey: .fontFamily)
        fontSize = try c.decode(Double.self, forKey: .fontSize)
        logInput = try c.decodeIfPresent(Bool.self, forKey: .logInput) ?? false
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
                let decoder = JSONDecoder()
                return try decoder.decode(SWSConfig.self, from: data)
            } catch {
                NSLog("SWS: failed to load config: \(error). Using defaults.")
                return .default
            }
        }

        // Create default config
        let config = SWSConfig.default
        config.save()
        return config
    }

    func save() {
        let fm = FileManager.default
        let dir = SWSConfig.configDir

        do {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: SWSConfig.configFile)
        } catch {
            NSLog("SWS: failed to save config: \(error)")
        }
    }

    func withSize(width: Double, height: Double) -> SWSConfig {
        var copy = self
        copy.width = width
        copy.height = height
        return copy
    }
}
