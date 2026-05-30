import Testing
import Foundation
@testable import sws

@Suite("Config v2")
struct ConfigTests {
    @Test
    func defaultIsV2() {
        let config = SWSConfig.default
        #expect(config.version == 2)
        #expect(config.defaultMode == "calc")
        #expect(config.modes.count == 1)
        #expect(config.modes[0].id == "calc")
        #expect(config.modes[0].type == "terminal")
    }

    @Test
    func v2RoundTripPreservesModes() throws {
        let original = SWSConfig.default
        let json = try JSONSerialization.data(withJSONObject: original.toJSON())
        let (parsed, migrated) = try SWSConfig.parse(data: json)

        #expect(migrated == false)
        #expect(parsed.version == 2)
        #expect(parsed.defaultMode == original.defaultMode)
        #expect(parsed.modes.count == original.modes.count)
        #expect(parsed.modes[0].id == original.modes[0].id)
        #expect(parsed.modes[0].hotkey == original.modes[0].hotkey)
        #expect(parsed.modes[0].raw["command"] as? String == "/usr/bin/bc")
    }

    @Test
    func v1ConfigMigratesToDefaultMode() throws {
        let v1 = """
        {
          "shortcut": { "key": "s", "modifiers": ["shift", "option"] },
          "command": "/usr/bin/python3",
          "args": [],
          "width": 800,
          "height": 500,
          "rememberSize": false,
          "fontFamily": "Courier",
          "fontSize": 16,
          "logInput": true
        }
        """.data(using: .utf8)!

        let (config, migrated) = try SWSConfig.parse(data: v1)
        #expect(migrated == true)
        #expect(config.version == 2)
        #expect(config.defaultMode == "default")
        #expect(config.modes.count == 1)
        #expect(config.modes[0].id == "default")
        #expect(config.modes[0].type == "terminal")
        #expect(config.modes[0].hotkey?.key == "s")
        #expect(config.modes[0].raw["command"] as? String == "/usr/bin/python3")
        #expect(config.width == 800)
        #expect(config.fontFamily == "Courier")
        #expect(config.logInput == true)
    }

    @Test
    func v1WithoutLogInputMigratesToFalse() throws {
        let v1 = """
        {
          "shortcut": { "key": "s", "modifiers": ["shift"] },
          "command": "/usr/bin/bc",
          "args": ["-l"],
          "width": 600, "height": 400,
          "rememberSize": true, "fontFamily": "Menlo", "fontSize": 14
        }
        """.data(using: .utf8)!

        let (config, _) = try SWSConfig.parse(data: v1)
        #expect(config.logInput == false)
    }

    @Test
    func v2MultipleModesParsedInOrder() throws {
        let v2 = """
        {
          "version": 2,
          "defaultMode": "calc",
          "modes": [
            { "id": "calc", "type": "terminal",
              "hotkey": { "key": "s", "modifiers": ["shift", "option"] },
              "command": "/usr/bin/bc", "args": ["-l"] },
            { "id": "py", "type": "terminal",
              "hotkey": { "key": "p", "modifiers": ["shift", "option"] },
              "command": "/usr/bin/python3", "args": [] }
          ],
          "width": 600, "height": 400, "rememberSize": true,
          "fontFamily": "Menlo", "fontSize": 14
        }
        """.data(using: .utf8)!

        let (config, migrated) = try SWSConfig.parse(data: v2)
        #expect(migrated == false)
        #expect(config.modes.map(\.id) == ["calc", "py"])
        #expect(config.mode(byID: "py")?.raw["command"] as? String == "/usr/bin/python3")
    }

    @Test
    func withSizeReturnsUpdatedCopy() {
        let original = SWSConfig.default
        let resized = original.withSize(width: 1024, height: 768)

        #expect(resized.width == 1024)
        #expect(resized.height == 768)
        #expect(resized.modes[0].id == original.modes[0].id)
        #expect(original.width == 600, "original should be unchanged")
    }
}
