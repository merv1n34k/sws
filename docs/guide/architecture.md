# Architecture

A quick map of how sws is put together. Useful before touching code.

## Layout

```
Sources/sws/
  main.swift                    Entry point, sets activation policy
  AppDelegate.swift             Wires modes, hotkeys, status menu
  ModeHostWindow.swift          The single floating panel that hosts modes
  HotkeyManager.swift           Carbon RegisterEventHotKey + dispatch
  Config.swift                  ~/.config/sws/config.json (v1 / v2 / tools migration)
  PreferencesWindow.swift       App-wide prefs (font, log)

  Modes/
    Mode.swift                  Mode protocol, registry, AppPrefs
    Builtins.swift              registerBuiltInModes()
    Shared/
      PersistentStore.swift     Codable JSON files under ~/.config/sws/
      Vision.swift              (free function in OCR/EnDe pipelines)
    Terminal/                   SwiftTerm-backed PTY mode
    Color/                      picker overlay + palette + contrast
    Timer/                      stopwatch · countdown · pomodoro · world · when-is
    Status/                     dashboard + menu-bar pin toggles
    EnDe/                       two-pane converter + 6 codecs
    Generators/                 password / uuid / lorem / random
    Clipboard/                  pasteboard monitor + history list
    OCR/                        Vision pipeline + PDF rasterization
    Scratchpad/                 single monospace text view

  MenuBar/
    MenuBarWidget.swift         Protocol + MenuBarRendering enum
    MenuBarWidgetRegistry.swift One NSStatusItem per pinned widget
```

## Core abstractions

### `Mode` protocol

`Sources/sws/Modes/Mode.swift`. Every visible feature is a `Mode`:

```swift
protocol Mode: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var preferredSize: NSSize? { get }
    var fixedSize: Bool { get }            // lock window to preferredSize

    func view() -> NSView                   // cached; called per activate
    func activate()                         // becoming the active mode
    func deactivate()                       // another mode takes over
    func windowDidShow()                    // window appeared (we're active)
    func windowDidHide()                    // window hid (we're active)
    func preferredFirstResponder() -> NSResponder?
}
```

Modes are long-lived — built once at launch, kept alive so timers /
PTYs keep running across mode switches and window hides.

### `ModeFactory` + `ModeRegistry`

Every mode is built by a factory from its config entry:

```swift
protocol ModeFactory {
    static var typeId: String { get }
    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode
}
```

`ModeRegistry.shared` maps `typeId` strings → factories. The core
never names a specific mode; `Builtins.swift` registers each built-in
in one line. Third-party modes drop into `Sources/sws/Modes/<Name>/`
and call `ModeRegistry.shared.register(...)` from a single registration
hook.

### `ModeHostWindow`

`Sources/sws/ModeHostWindow.swift`. One NSPanel that:

- Holds the currently active mode's view.
- Swaps subviews on `switchMode(_:)` and applies `preferredSize` /
  `fixedSize`.
- Dispatches `windowDidShow` / `windowDidHide` lifecycle.
- Tracks the most-recently-active non-sws app via
  `NSWorkspace.didActivateApplicationNotification` and restores it on
  hide.
- Set to dark appearance, so all hosted modes get dark-mode system
  controls.

### `HotkeyManager`

Wraps Carbon `RegisterEventHotKey`. Supports multiple registrations
keyed by mode id. The Carbon event handler is installed exactly once
and dispatches by hotkey id back to per-mode callbacks. Mode-specific
hotkeys are registered when the window shows and unregistered when it
hides so they don't pollute the global hotkey space.

## Hotkey routing flow

```
[user presses ⌥⇧T]
   ↓
HotkeyManager (carbon callback)
   ↓
AppDelegate.handleModeHotkey("timer")
   ↓
ModeHostWindow.switchMode(timerMode)        if visible
ModeHostWindow.show(mode: timerMode)         if hidden
```

## Menu-bar widget framework

`Sources/sws/MenuBar/`. Independent from the Mode system.

```swift
protocol MenuBarWidget: AnyObject {
    var id: String { get }
    var pollInterval: TimeInterval { get }
    func render() -> MenuBarRendering
    func currentValue() -> String      // for dashboard buttons
}
```

`MenuBarWidgetRegistry.shared` owns one `NSStatusItem` + polling
`Timer` per active widget, persists the pinned-id set to
`~/.config/sws/menubar.json`, and re-spawns pinned widgets on launch.
The Status mode is the only thing that pins/unpins widgets — but
nothing in the framework is mode-specific.

## Persistent state

`PersistentStore<Value: Codable>` is a one-line read/write helper for
JSON files under `~/.config/sws/`. Used by Clipboard
(`clipboard.json` + `clipboard-images/`), Scratchpad
(`scratchpad.md`), and the menu-bar widget registry
(`menubar.json`).

## Build pipeline

- `swift build` compiles to `.build/release/sws` (a bare Mach-O).
- `scripts/generate-icon.swift` renders an .iconset → `iconutil` → .icns.
- `Makefile` wraps the binary in `SWS.app/Contents/`:
  - `MacOS/sws` — the executable
  - `Info.plist` — bundle id `com.merv1n34k.sws`, `LSUIElement=true`,
    Screen Recording usage description
  - `Resources/AppIcon.icns` + `MenuBarIcon.png` + `MenuBarIcon@2x.png`
  - Ad-hoc code signature via `codesign --sign -`
- `make install` copies `SWS.app` to `/Applications`, strips
  quarantine, resets the TCC Screen Recording grant.

## Testing

- `make test` runs `swift test`.
- 60+ unit tests across `Tests/swsTests/`:
  - Config round-trip + v1/tools migration
  - Hotkey parsing
  - ANSI stripping
  - Color formatting + Oklab + k-means + contrast
  - Generators (password / UUID / lorem / random)
  - DatePhraseParser
  - EnDe codecs (Base64 / URL / CSV-MD / JWT round-trips)
- UI / window-level behavior is tested manually — no UI test target.
