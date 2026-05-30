# SWS — Swift Window Shell

Lightweight native macOS menu bar app that opens a floating window on a
global hotkey. The window hosts a **mode**: by default a terminal
running `bc`, but Timer and Color (picker + palette extractor) modes
ship in the box, and new modes drop in as source files under
`Sources/sws/Modes/`.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Global hotkey opens sws** in the default mode (Shift+Option+S → `bc`)
- **Built-in modes**:
  - **Terminal** — any program, with full emulation via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (arrow keys, history, colors, readline). Configure one terminal mode per command (calc, python, ruby, …).
  - **Timer** — stopwatch, countdown (`5m`, `1h30m`, `1:30:00`), world clock with UTC offsets or IANA zones. Countdown completion fires a system notification even if the window is hidden.
  - **Color** — color picker + drag-to-extract palette. Click a pixel for a single color, or drag a rectangle and the captured region is clustered (sRGB → Oklab → k-means++) into 8 dominant colors. HEX/RGB/HSL/HSB rows with per-format copy; clicking the palette strip copies the whole palette as a hex CSV. The clusterer is a minimal local take on [Okolors](https://github.com/Ivordir/Okolors).
- **Per-mode hotkeys** are intercepted only while sws is open — pressing them outside passes through to whatever app is frontmost.
- **Borderless rounded window** that stays on top of all apps; **Escape** hides; **Option+Drag** moves.
- **Tmux-style copy** in terminal mode: select text and it's copied on release.
- **JSON config** at `~/.config/sws/config.json` with `Reload Config` from the menu.

## Install

### From release

```bash
# Download the latest release from GitHub
tar xzf sws-v*.tar.gz
sudo mv sws /usr/local/bin/
```

### From source

```bash
git clone https://github.com/merv1n34k/sws.git
cd sws
make build
make install  # sudo cp .build/release/sws /usr/local/bin/sws
```

## Usage

Launch `sws` — a terminal icon appears in the menu bar.

| Action                          | Effect                                                        |
|---------------------------------|---------------------------------------------------------------|
| **Shift+Option+S**              | Open/hide window in default mode (calc)                       |
| **Mode hotkey** (while open)    | Switch to that mode; press again to return to default         |
| **Escape**                      | Hide window                                                   |
| **Option+Drag**                 | Move window                                                   |
| **Click+Drag** (terminal mode)  | Select text (auto-copied to clipboard)                        |

Mode hotkeys only respond when the window is already open. So
Shift+Option+T only switches to the Timer mode while sws is showing —
it doesn't trigger anything when sws is hidden.

## Configuration

`~/.config/sws/config.json` (created on first launch):

```json
{
  "version": 2,
  "defaultMode": "calc",
  "modes": [
    {
      "id": "calc",
      "type": "terminal",
      "hotkey": { "key": "s", "modifiers": ["shift", "option"] },
      "command": "/usr/bin/bc",
      "args": ["-l"]
    },
    {
      "id": "python",
      "type": "terminal",
      "hotkey": { "key": "p", "modifiers": ["shift", "option"] },
      "command": "/usr/bin/python3"
    },
    {
      "id": "timer",
      "type": "timer",
      "hotkey": { "key": "t", "modifiers": ["shift", "option"] },
      "defaultSubMode": "countdown",
      "worldClocks": ["UTC+0", "UTC+3", "America/New_York"]
    },
    {
      "id": "color",
      "type": "color",
      "hotkey": { "key": "c", "modifiers": ["shift", "option"] }
    }
  ],
  "width": 600,
  "height": 400,
  "rememberSize": true,
  "fontFamily": "Menlo",
  "fontSize": 14,
  "logInput": false
}
```

The first mode in `modes` is the default unless `defaultMode` says
otherwise. Old single-terminal v1 configs are migrated automatically on
first launch.

App-wide preferences (font, logging, remember-size) are also editable
via **Preferences...** in the menu bar dropdown.

## Adding a mode

1. Drop a new file under `Sources/sws/Modes/<YourMode>/` implementing the `Mode` and `ModeFactory` protocols (see `Modes/Mode.swift`).
2. Register it in `Modes/Builtins.swift`:
   ```swift
   ModeRegistry.shared.register(YourModeFactory.self)
   ```
3. Add an entry to your `config.json` with `"type": "<your-typeId>"`.

The core never references modes by name — `ModeRegistry` looks them up by `typeId`.

## Requirements

- macOS 13+
- Apple Silicon or Intel Mac

## License

Distributed under MIT license, see `LICENSE` for more.
