# Clipboard

Pasteboard history with search and persistence.

## Hotkey

Default: **⌥⇧A** (cliboArd).

## Layout

```
┌────────────────────────────────────────────────┐
│  🔎 [ filter ]                  [ Clear all ]  │
├────────────────────────────────────────────────┤
│  3m ago   📝  https://example.com/path/...     │
│  8m ago   📝  function add(a, b) { return ...  │
│  21m ago  🖼   image 1280×720, 86 KB            │
│  1h ago   📝  Lorem ipsum dolor sit amet, …    │
│  …                                             │
└────────────────────────────────────────────────┘
```

## Behavior

- A `Timer` polls `NSPasteboard.changeCount` every ~500 ms.
- New entries appear at the top of the list.
- **Double-click** an entry → puts it back on the pasteboard.
- **Right-click** for **Delete entry** / **Clear all**.
- Search box filters by case-insensitive substring on the entry text
  (image entries match their dimensions).

## Caps

To keep storage bounded:

| Cap | Default | Configurable as |
|---|---|---|
| Total entries | 500 | `clipboardMaxEntries` |
| Text per entry | 1 MB (truncated past that) | `clipboardMaxEntryBytes` |
| Image per entry | 1 MB (skipped past that, shown as `(image too large, X MB)`) | `clipboardMaxEntryBytes` |

When the entry cap is hit, the oldest entry is dropped.

Set higher values in `~/.config/sws/config.json` for a more persistent
history:

```json
"clipboardMaxEntries": 5000,
"clipboardMaxEntryBytes": 5000000
```

## Persistence

- Index → `~/.config/sws/clipboard.json`
- Image thumbnails → `~/.config/sws/clipboard-images/<uuid>.png`

History survives restarts. Delete the directory to wipe it.

## Configuration

No mode-specific options.

```json
{
  "id": "clipboard",
  "type": "clipboard",
  "hotkey": { "key": "v", "modifiers": ["shift", "option"] }
}
```

## Implementation pointers

- `Sources/sws/Modes/Clipboard/ClipboardMonitor.swift` — change-count poller
- `Sources/sws/Modes/Clipboard/ClipboardEntry.swift` — Codable entry model
- `Sources/sws/Modes/Clipboard/ClipboardView.swift` — search + table view
- `Sources/sws/Modes/Shared/PersistentStore.swift` — JSON storage helper
