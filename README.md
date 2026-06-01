# SWS — Swift Window Shell

Lightweight native macOS menu-bar utility belt. Press a hotkey, a small
floating window opens with the tool you asked for. Press it again, it
goes away and your focus returns to whatever you were doing.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Modes

| Mode | Hotkey | What it does |
|---|---|---|
| **Terminal** | ⌥⇧S | Any CLI program (default: `bc -l`). Configure one per command. |
| **Color** | ⌥⇧C | Pixel picker, drag-region palette extractor (Oklab k-means), HEX/RGB/HSL/HSB readouts, WCAG contrast checker. |
| **Time** | ⌥⇧Q | Stopwatch · Countdown · Pomodoro · World clocks · NLP date phrases ("20 hours from now"). |
| **Status** | ⌥⇧D | Pinnable menu-bar widgets for CPU/RAM/SSD/Network + IP, Wi-Fi, ports & HTTP status lookups. |
| **EnDe** | ⌥⇧E | Two-pane converter: Base64 · URL · CSV ↔ Markdown · JWT · QR · Barcode. |
| **Generators** | ⌥⇧X | Password · UUID (v4/v7/ULID) · Lorem ipsum · Random picker. |
| **Clipboard** | ⌥⇧A | Pasteboard history with search, configurable cap, image thumbnails. |
| **OCR** | ⌥⇧R | Drop an image/PDF, get text via Vision. |
| **Scratchpad** | ⌥⇧W | Persistent monospace text. Autosaves. |

All shortcuts are on the left half of the keyboard for one-hand reach.
Mode hotkeys only fire when the window is already open — outside of that
they pass through to whatever app is frontmost.

## Install

```bash
git clone https://github.com/merv1n34k/sws.git
cd sws
make install      # builds SWS.app, copies to /Applications, resets TCC
open /Applications/SWS.app
```

First launch will prompt for **Screen Recording** permission (needed by
the color picker and OCR). Grant it in System Settings → Privacy &
Security → Screen Recording, then quit and reopen.

## Configure

Mode list lives at `~/.config/sws/config.json`. Example:

```json
{
  "version": 2,
  "defaultMode": "calc",
  "modes": [
    { "id": "calc", "type": "terminal",
      "hotkey": { "key": "s", "modifiers": ["shift", "option"] },
      "command": "/usr/bin/bc", "args": ["-l"] },
    { "id": "ende", "type": "ende",
      "hotkey": { "key": "e", "modifiers": ["shift", "option"] } }
  ],
  "fontFamily": "Menlo",
  "fontSize": 14
}
```

Full schema and per-mode options in the
[Configuration guide](docs/guide/configuration.md).

## Docs

Full documentation lives under `docs/` as a VitePress site:

```bash
make docs    # serves http://localhost:5173 (runs `bun install` on first use)
```

Highlights:
- [Installation](docs/guide/installation.md)
- [Configuration](docs/guide/configuration.md)
- [Hotkey conventions](docs/guide/hotkeys.md)
- [Architecture](docs/guide/architecture.md)
- [Adding a mode](docs/guide/adding-modes.md)
- Per-mode reference under [docs/modes/](docs/modes/)

## Requirements

- macOS 13+ (Ventura)
- Apple Silicon or Intel
- Xcode command line tools (`swift`, `codesign`, `iconutil`)

## License

MIT — see `LICENSE`.
