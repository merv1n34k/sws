import Testing
import Foundation
import Carbon
@testable import sws

@Suite("Hotkey parsing")
struct HotkeyTests {
    @Test
    func virtualKeyCodeMappedKeys() {
        #expect(HotkeyManager.virtualKeyCode(for: "a") == 0x00)
        #expect(HotkeyManager.virtualKeyCode(for: "s") == 0x01)
        #expect(HotkeyManager.virtualKeyCode(for: "space") == 0x31)
        #expect(HotkeyManager.virtualKeyCode(for: "escape") == 0x35)
        #expect(HotkeyManager.virtualKeyCode(for: "return") == 0x24)
    }

    @Test
    func virtualKeyCodeIsCaseInsensitive() {
        #expect(HotkeyManager.virtualKeyCode(for: "S") == HotkeyManager.virtualKeyCode(for: "s"))
        #expect(HotkeyManager.virtualKeyCode(for: "SPACE") == HotkeyManager.virtualKeyCode(for: "space"))
    }

    @Test
    func virtualKeyCodeUnknownReturnsNil() {
        #expect(HotkeyManager.virtualKeyCode(for: "zzz") == nil)
        #expect(HotkeyManager.virtualKeyCode(for: "f1") == nil)
        #expect(HotkeyManager.virtualKeyCode(for: "") == nil)
    }

    @Test
    func carbonModifiersAliases() {
        #expect(HotkeyManager.carbonModifiers(from: ["cmd"]) == cmdKey)
        #expect(HotkeyManager.carbonModifiers(from: ["command"]) == cmdKey)
        #expect(HotkeyManager.carbonModifiers(from: ["alt"]) == optionKey)
        #expect(HotkeyManager.carbonModifiers(from: ["option"]) == optionKey)
        #expect(HotkeyManager.carbonModifiers(from: ["ctrl"]) == controlKey)
        #expect(HotkeyManager.carbonModifiers(from: ["control"]) == controlKey)
        #expect(HotkeyManager.carbonModifiers(from: ["shift"]) == shiftKey)
    }

    @Test
    func carbonModifiersCaseInsensitive() {
        #expect(HotkeyManager.carbonModifiers(from: ["SHIFT"]) == shiftKey)
        #expect(HotkeyManager.carbonModifiers(from: ["Option"]) == optionKey)
    }

    @Test
    func carbonModifiersCombines() {
        let mods = HotkeyManager.carbonModifiers(from: ["shift", "option"])
        #expect(mods == shiftKey | optionKey)
    }

    @Test
    func carbonModifiersUnknownIsIgnored() {
        let mods = HotkeyManager.carbonModifiers(from: ["shift", "bogus", "option"])
        #expect(mods == shiftKey | optionKey)
    }
}

@Suite("ANSI stripping")
struct AnsiTests {
    @Test
    func removesColorCodes() {
        let input = "\u{1B}[31mHello\u{1B}[0m world\n".data(using: .utf8)!
        let stripped = TerminalView.stripAnsi(input)
        #expect(String(data: stripped, encoding: .utf8) == "Hello world\n")
    }

    @Test
    func removesOscSequence() {
        let input = "\u{1B}]0;title\u{07}body\n".data(using: .utf8)!
        let stripped = TerminalView.stripAnsi(input)
        #expect(String(data: stripped, encoding: .utf8) == "body\n")
    }

    @Test
    func passesThroughPlainText() {
        let input = "plain text\n".data(using: .utf8)!
        #expect(TerminalView.stripAnsi(input) == input)
    }

    @Test
    func dropsBareCarriageReturn() {
        let input = "abc\rdef\n".data(using: .utf8)!
        let stripped = TerminalView.stripAnsi(input)
        #expect(String(data: stripped, encoding: .utf8) == "abcdef\n")
    }
}
