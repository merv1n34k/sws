# Adding a mode

Every built-in mode is ~3 files in `Sources/sws/Modes/<Name>/`. Adding
a new one means writing a `Mode` conformance, a `ModeFactory`, and
plugging it into the registry. The core never references the new mode
by name — it's discovered through the `typeId` you declare.

## Skeleton

```swift
// Sources/sws/Modes/Hello/HelloMode.swift
import AppKit

final class HelloMode: Mode {
    let id: String
    let displayName: String
    let preferredSize: NSSize? = NSSize(width: 360, height: 200)

    private lazy var rootView = HelloView()

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func view() -> NSView { rootView }
}

enum HelloModeFactory: ModeFactory {
    static let typeId = "hello"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let name = (instance.raw["displayName"] as? String) ?? "Hello"
        return HelloMode(id: instance.id, displayName: name)
    }
}
```

The view is just an `NSView`:

```swift
// Sources/sws/Modes/Hello/HelloView.swift
import AppKit

final class HelloView: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor
        let label = NSTextField(labelWithString: "Hello, sws!")
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
```

## Register

Single line in `Sources/sws/Modes/Builtins.swift`:

```swift
func registerBuiltInModes() {
    // … existing lines …
    ModeRegistry.shared.register(HelloModeFactory.self)
}
```

## Add to config

```json
{
  "id": "hello",
  "type": "hello",
  "hotkey": { "key": "h", "modifiers": ["shift", "option"] }
}
```

Reload from the menu bar and ⌥⇧H summons your mode.

## Configurable options

The `instance.raw` dictionary in `make(...)` holds every JSON field of
that mode entry. Read your own fields directly:

```swift
let count = (instance.raw["count"] as? Int) ?? 5
```

Add a corresponding config example to your mode's docs page.

## Mode lifecycle

The methods you can override on `Mode`:

| Method | When called |
|---|---|
| `activate()` | This mode just became the active mode |
| `deactivate()` | Another mode is taking over |
| `windowDidShow()` | Host window appeared (only fired on the active mode) |
| `windowDidHide()` | Host window hid (only fired on the active mode) |
| `preferredFirstResponder()` | Window asks who should receive keystrokes |
| `view()` | Return your NSView. Cache it (lazy var). |

Mode objects are **long-lived** — built once at launch, never destroyed.
Use them to hold state that should survive window hides and mode
switches (PTYs, timers, accumulated history).

## Fixed window size

If your mode's layout is a fixed grid that shouldn't be resized:

```swift
let preferredSize: NSSize? = NSSize(width: 440, height: 340)
let fixedSize: Bool = true
```

`ModeHostWindow` will lock the window to those dimensions and disable
the resize handle while your mode is active. See `StatusMode` for an
example.

## Common patterns

Use these helpers instead of rolling your own:

- **Persistent state** — `PersistentStore<MyState>` (Codable JSON under
  `~/.config/sws/<file>`).
- **Two-pane converter** — extend `EnDeCodec` and let the existing
  `TwoPaneConverter` host you. See `Modes/EnDe/Codecs/`.
- **Menu-bar widget** — implement `MenuBarWidget` and register a
  factory with `MenuBarWidgetRegistry.shared`.
- **Sub-modes with segmented control** — pattern is in
  `TimerView.swift` and `GeneratorsView.swift`. Top-level segmented
  control, container `NSView` below, swap subviews on selection
  change.

## Style notes

- AppKit only — no SwiftUI in this codebase.
- Force dark colors on labels / text fields if they need to read on
  the dark backdrop (the host window forces dark appearance, but some
  NSButton checkboxes ignore it — set `attributedTitle` explicitly).
- Don't introduce new dependencies without discussion; everything in
  the codebase is built on AppKit + Foundation + Vision + CoreImage +
  CoreWLAN, all built into macOS.

## Tests

Pure-logic helpers go in `Tests/swsTests/<Name>Tests.swift` using the
Swift Testing framework (`import Testing`). Examples: `Generators`,
`DatePhraseParser`, `Contrast`, the EnDe codecs. UI / window
interactions are exercised manually.
