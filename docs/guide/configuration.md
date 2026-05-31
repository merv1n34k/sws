# Configuration

Mode list, hotkeys, fonts, and per-mode options live in a single JSON
file:

```
~/.config/sws/config.json
```

sws creates a default one on first launch. Edit it any time and pick
**Reload Config** from the menu bar dropdown to apply, or quit and
reopen.

## Top-level schema

```json
{
  "version": 2,
  "defaultMode": "calc",
  "modes": [ ... ],
  "width": 460,
  "height": 360,
  "rememberSize": true,
  "fontFamily": "Menlo",
  "fontSize": 14,
  "logInput": false
}
```

| Field | Default | Meaning |
|---|---|---|
| `version` | `2` | Schema version. Older configs are migrated automatically on load. |
| `defaultMode` | `"calc"` | `id` of the mode opened by the summon hotkey when sws is hidden. |
| `modes` | `[]` | Ordered list of mode entries. See below. |
| `width` / `height` | `460 / 360` | Initial window size in points. Saved on resize when `rememberSize` is true. |
| `rememberSize` | `true` | Persist size changes back into this file. |
| `fontFamily` / `fontSize` | `Menlo / 14` | Used by terminal modes for the PTY view. |
| `logInput` | `false` | Mirror terminal output (post-ANSI stripping) to `~/.sws.log`. |

## Mode entry

Every entry in `modes` has these common fields, plus type-specific extras:

```json
{
  "id": "calc",
  "type": "terminal",
  "displayName": "Calc",          // optional, defaults to id.capitalized
  "hotkey": { "key": "s", "modifiers": ["shift", "option"] }
}
```

- **`id`** — unique within the config; used in URLs and the status menu.
- **`type`** — drives which factory builds the mode (see table below).
- **`hotkey`** — Carbon-style global hotkey. Modifiers are any subset of
  `["shift", "option", "command", "control"]`. Keys are letter names
  (`"a".."z"`), digits, or special names (`"return"`, `"escape"`,
  `"tab"`, `"space"`, `"`"`, `"-"`, `"="`, `"["`, `"]"`, `"\\"`, `";"`,
  `"'"`, `","`, `"."`, `"/"`).

## Type reference

| `type` | Built-in factory | Extra fields | Page |
|---|---|---|---|
| `terminal` | `TerminalModeFactory` | `command`, `args` | [Terminal](/modes/terminal) |
| `color` | `ColorModeFactory` | — | [Color](/modes/color) |
| `timer` | `TimerModeFactory` | `defaultSubMode`, `worldClocks`, `pomodoroWorkMinutes`, `pomodoroBreakMinutes` | [Time](/modes/time) |
| `status` | `StatusModeFactory` | — | [Status](/modes/status) |
| `ende` | `EnDeModeFactory` | — | [EnDe](/modes/ende) |
| `generators` | `GeneratorsModeFactory` | — | [Generators](/modes/generators) |
| `clipboard` | `ClipboardModeFactory` | — | [Clipboard](/modes/clipboard) |
| `ocr` | `OCRModeFactory` | — | [OCR](/modes/ocr) |
| `scratchpad` | `ScratchpadModeFactory` | — | [Scratchpad](/modes/scratchpad) |

## Full example

```json
{
  "version": 2,
  "defaultMode": "calc",
  "modes": [
    {
      "id": "calc", "type": "terminal",
      "hotkey": { "key": "s", "modifiers": ["shift", "option"] },
      "command": "/usr/bin/bc", "args": ["-l"]
    },
    {
      "id": "py", "type": "terminal",
      "hotkey": { "key": "p", "modifiers": ["shift", "option"] },
      "command": "/usr/bin/python3"
    },
    {
      "id": "color", "type": "color",
      "hotkey": { "key": "c", "modifiers": ["shift", "option"] }
    },
    {
      "id": "timer", "type": "timer",
      "hotkey": { "key": "t", "modifiers": ["shift", "option"] },
      "defaultSubMode": "countdown",
      "worldClocks": ["UTC+0", "UTC+3", "America/New_York"],
      "pomodoroWorkMinutes": 25,
      "pomodoroBreakMinutes": 5
    },
    {
      "id": "status", "type": "status",
      "hotkey": { "key": "d", "modifiers": ["shift", "option"] }
    },
    {
      "id": "ende", "type": "ende",
      "hotkey": { "key": "e", "modifiers": ["shift", "option"] }
    },
    {
      "id": "generators", "type": "generators",
      "hotkey": { "key": "g", "modifiers": ["shift", "option"] }
    },
    {
      "id": "clipboard", "type": "clipboard",
      "hotkey": { "key": "v", "modifiers": ["shift", "option"] }
    },
    {
      "id": "ocr", "type": "ocr",
      "hotkey": { "key": "r", "modifiers": ["shift", "option"] }
    },
    {
      "id": "scratchpad", "type": "scratchpad",
      "hotkey": { "key": "w", "modifiers": ["shift", "option"] }
    }
  ],
  "width": 460,
  "height": 360,
  "rememberSize": true,
  "fontFamily": "Menlo",
  "fontSize": 14,
  "logInput": false
}
```

## State files

Persistent state outside the config lives under `~/.config/sws/`:

| File | Owner |
|---|---|
| `config.json` | This file |
| `scratchpad.md` | Scratchpad mode (autosaved on edit) |
| `clipboard.json` + `clipboard-images/` | Clipboard mode |
| `menubar.json` | Pinned widgets (from the Status dashboard) |

Wipe `~/.config/sws/` to reset everything; on the next launch the
default config is regenerated.

## Migration

Older config schemas are migrated automatically on load:

- **v1** (single top-level `command`/`args`/`shortcut`) → wrapped into a
  single `default` terminal mode.
- **Tools-array** (`tools: [...]`) → each tool becomes a mode entry,
  with the first tool inheriting the top-level summon `shortcut`.

The migrated v2 file is written back to disk on first load.
