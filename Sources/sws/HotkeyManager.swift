import Carbon
import AppKit

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    // Singleton so the C callback can reach us
    static var shared: HotkeyManager?

    init() {
        HotkeyManager.shared = self
    }

    func register(key: String, modifiers: [String], callback: @escaping () -> Void) {
        unregister()
        self.callback = callback

        let keyCode = virtualKeyCode(for: key)
        let mods = carbonModifiers(from: modifiers)

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                HotkeyManager.shared?.callback?()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        let hotkeyID = EventHotKeyID(signature: 0x5357_5348, id: 1) // "SWSH"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(mods),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotkeyRef = ref
            NSLog("SWS: hotkey registered (key=\(key), mods=\(modifiers))")
        } else {
            NSLog("SWS: failed to register hotkey: \(status)")
        }
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    private func carbonModifiers(from names: [String]) -> Int {
        var mods = 0
        for name in names {
            switch name.lowercased() {
            case "command", "cmd":
                mods |= cmdKey
            case "option", "alt":
                mods |= optionKey
            case "control", "ctrl":
                mods |= controlKey
            case "shift":
                mods |= shiftKey
            default:
                NSLog("SWS: unknown modifier '\(name)'")
            }
        }
        return mods
    }

    private func virtualKeyCode(for key: String) -> Int {
        let map: [String: Int] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
            "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
            "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
            "y": 0x10, "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19, "7": 0x1A,
            "8": 0x1C, "0": 0x1D, "o": 0x1F, "u": 0x20, "i": 0x22,
            "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D,
            "m": 0x2E, "space": 0x31, "return": 0x24, "escape": 0x35,
            "tab": 0x30, "`": 0x32, "-": 0x1B, "=": 0x18,
            "[": 0x21, "]": 0x1E, "\\": 0x2A, ";": 0x29, "'": 0x27,
            ",": 0x2B, ".": 0x2F, "/": 0x2C,
        ]
        return map[key.lowercased()] ?? 0x01 // default to 's'
    }
}
