import Carbon
import AppKit

/// Manages multiple Carbon global hotkeys, one per mode id. Modes can
/// be registered and unregistered independently as the window
/// shows/hides; the Carbon event handler is installed exactly once and
/// dispatches by hotkey id back to the per-mode callback.
final class HotkeyManager {
    private struct Registration {
        let modeID: String
        let ref: EventHotKeyRef
        let callback: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]   // by Carbon hotKeyID.id
    private var byModeID: [String: UInt32] = [:]              // mode id → hotKeyID.id
    private var nextID: UInt32 = 1
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x5357_5348        // "SWSH"

    deinit {
        unregisterAll()
        if let h = handlerRef {
            RemoveEventHandler(h)
        }
    }

    @discardableResult
    func register(modeID: String, key: String, modifiers: [String], callback: @escaping () -> Void) -> Bool {
        unregister(modeID: modeID)

        guard let keyCode = HotkeyManager.virtualKeyCode(for: key) else {
            NSLog("SWS: unknown hotkey key '\(key)' for mode '\(modeID)' — not registering")
            return false
        }
        let mods = HotkeyManager.carbonModifiers(from: modifiers)

        installHandlerIfNeeded()

        let id = nextID
        nextID &+= 1
        let hotkeyID = EventHotKeyID(signature: HotkeyManager.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(mods),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref = ref else {
            NSLog("SWS: failed to register hotkey for mode '\(modeID)': \(status)")
            return false
        }
        registrations[id] = Registration(modeID: modeID, ref: ref, callback: callback)
        byModeID[modeID] = id
        NSLog("SWS: hotkey registered for mode '\(modeID)' (key=\(key), mods=\(modifiers))")
        return true
    }

    func unregister(modeID: String) {
        guard let id = byModeID.removeValue(forKey: modeID),
              let reg = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(reg.ref)
    }

    func unregisterAll(except keep: String? = nil) {
        let keepID = keep.flatMap { byModeID[$0] }
        for (id, reg) in registrations where id != keepID {
            UnregisterEventHotKey(reg.ref)
        }
        registrations = registrations.filter { $0.key == keepID }
        byModeID = byModeID.filter { $0.value == keepID }
    }

    func isRegistered(modeID: String) -> Bool {
        byModeID[modeID] != nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if status == noErr, let reg = manager.registrations[hkID.id] {
                    reg.callback()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
    }

    static func carbonModifiers(from names: [String]) -> Int {
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

    static func virtualKeyCode(for key: String) -> Int? {
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
        return map[key.lowercased()]
    }
}
