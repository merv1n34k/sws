import Testing
import Foundation
@testable import sws

@Suite("Config")
struct ConfigTests {
    @Test
    func defaultRoundTrip() throws {
        let original = SWSConfig.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SWSConfig.self, from: data)

        #expect(decoded.command == original.command)
        #expect(decoded.args == original.args)
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
        #expect(decoded.rememberSize == original.rememberSize)
        #expect(decoded.fontFamily == original.fontFamily)
        #expect(decoded.fontSize == original.fontSize)
        #expect(decoded.logInput == original.logInput)
        #expect(decoded.shortcut.key == original.shortcut.key)
        #expect(decoded.shortcut.modifiers == original.shortcut.modifiers)
    }

    @Test
    func legacyConfigWithoutLogInputDefaultsToFalse() throws {
        let legacy = """
        {
          "shortcut": { "key": "s", "modifiers": ["shift", "option"] },
          "command": "/usr/bin/bc",
          "args": ["-l"],
          "width": 600,
          "height": 400,
          "rememberSize": true,
          "fontFamily": "Menlo",
          "fontSize": 14
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SWSConfig.self, from: legacy)
        #expect(decoded.logInput == false)
    }

    @Test
    func withSizeReturnsUpdatedCopy() {
        let original = SWSConfig.default
        let resized = original.withSize(width: 1024, height: 768)

        #expect(resized.width == 1024)
        #expect(resized.height == 768)
        #expect(resized.command == original.command)
        #expect(original.width == 600, "original should be unchanged")
    }
}
