# Scratchpad

One persistent monospace text view. The "where did I put that thing"
buffer.

## Hotkey

Default: **⌥⇧W** (Write).

## Layout

```
┌────────────────────────────────────────────────┐
│                                                │
│   (NSTextView, monospace, autosaves)           │
│                                                │
│                                                │
└────────────────────────────────────────────────┘
```

No toolbar. No formatting. No tabs. Just text.

## Behavior

- Single buffer, monospace font (matches your global `fontFamily` /
  `fontSize`).
- **Autosaves** on every edit, debounced at 0.4 s.
- Persists to `~/.config/sws/scratchpad.md` — readable / writable as
  a plain Markdown file by any other tool.
- Survives restarts, mode switches, window hides.

## Common uses

- Capture a thought without context-switching.
- Stash text mid-paste-and-modify.
- Quick to-do list (the file is Markdown — your habits work).
- Place to dump a regex / SQL snippet you'll need in five minutes.

## Configuration

No mode-specific options.

```json
{
  "id": "scratchpad",
  "type": "scratchpad",
  "hotkey": { "key": "w", "modifiers": ["shift", "option"] }
}
```

## Implementation pointers

- `Sources/sws/Modes/Scratchpad/ScratchpadView.swift` — single NSTextView with debounce
- `Sources/sws/Modes/Shared/PersistentStore.swift` — file IO helper
