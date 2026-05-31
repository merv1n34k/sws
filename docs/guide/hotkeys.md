# Hotkeys

sws is hotkey-first. The whole point is that you don't go looking for
windows or menus — you hit a key, the tool is there.

## Default bindings

All defaults use **⌥⇧letter** with letters on the left half of the
keyboard for one-hand reach.

| Mode | Hotkey |
|---|---|
| Terminal (calc) | ⌥⇧S |
| Color | ⌥⇧C |
| Time | ⌥⇧T |
| Status | ⌥⇧D |
| EnDe | ⌥⇧E |
| Generators | ⌥⇧G |
| Clipboard | ⌥⇧V |
| OCR | ⌥⇧R |
| Scratchpad | ⌥⇧W |

You can pick any combination — `command`, `option`, `shift`, `control`
plus a letter / digit / common key. See
[Configuration](./configuration#mode-entry).

## Behavior

### Default-mode hotkey (the summon key)

- sws hidden → opens window in the default mode.
- sws visible in default mode → hides window.
- sws visible in another mode → switches to default mode.

### Mode-specific hotkeys

Only registered while the sws window is visible — they don't intercept
keypresses while sws is hidden, so they pass through to whatever app is
frontmost.

- sws visible in this mode → switches back to default.
- sws visible in another mode → switches to this mode.

This means you can keep `⌥⇧T` for "Timer" mode bound system-wide without
worrying about it conflicting with another app — sws only grabs it when
its own window is up.

## Focus restore

When you hide sws (via hotkey, **Escape**, or the menu), focus returns
to the **most recently active non-sws app**. This is tracked
continuously via `NSWorkspace.didActivateApplicationNotification`, so
even if you Cmd-Tabbed to a different app while sws was open, hiding
sends you back to that recent app, not whatever was frontmost when sws
was first summoned.

## Inside the window

- **Escape** — hide.
- **⌥+drag** — move the window (any mode).
- Drag the bottom-right corner to resize (modes that allow it).

## Mode-specific input

| Mode | Notes |
|---|---|
| Terminal | All keystrokes go to the spawned program. ⌥-as-Meta is enabled. |
| Color | Picker overlay is always-on while this mode is visible: click for pixel, drag for region. |
| Time | Type a number + Enter for countdown; type a phrase for When-is. |
| Status | Click a stat button to pin / unpin its menu-bar widget. |
| EnDe | Bidirectional codecs accept input in either pane. |
| Clipboard | Double-click an entry to put it back on the pasteboard. |
| OCR | Drop image / PDF, or click "Pick screen region" / "Browse…" / "Paste from clipboard". |

## Choosing your own bindings

Left-hand-only is a suggestion, not a constraint. The
[Configuration](./configuration) page covers the JSON schema. A few
things to keep in mind:

- Avoid colliding with macOS system shortcuts (⌘⇧3, ⌘⇧4, ⌘⇧5, ⌘Space, …).
- Avoid colliding with bindings in apps you keep frontmost — the mode
  hotkeys only intercept when sws is open, but the **default** mode's
  hotkey is registered globally and will swallow that key combination.
- Mode hotkeys can share a modifier set; only the default-mode hotkey
  needs to be globally distinctive.
