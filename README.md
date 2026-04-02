# SWS — Swift Window Shell

Lightweight native macOS menu bar app that opens a floating terminal window on a global hotkey.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Global hotkey** (Shift+Option+S) toggles a floating terminal
- **Full terminal emulation** via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) — arrow keys, history, colors, readline
- **Configurable command** — default `bc -l`, set to `python3`, `irb`, etc.
- **Borderless rounded window** that stays on top of all apps
- **Focus restore** — hides and returns focus to the previous app
- **Preferences UI** + JSON config at `~/.config/sws/config.json`
- **Input logging** — optionally log entered commands to `~/.sws.log`
- **Tmux-style copy** — select text and it's copied to clipboard on release
- **Option+drag** to reposition the window

## Install

### From release

```bash
# Download the latest release from GitHub
tar xzf sws-v*.tar.gz
mv sws /usr/local/bin/
```

### From source

```bash
git clone https://github.com/merv1n34k/sws.git
cd sws
make build
make install  # copies to /usr/local/bin
```

## Usage

Launch `sws` — a terminal icon appears in the menu bar.

| Action | Effect |
|---|---|
| **Shift+Option+S** | Toggle terminal window |
| **Escape** | Hide terminal window |
| **Option+Drag** | Move window |
| **Click+Drag** | Select text (auto-copied to clipboard) |

## Configuration

Config lives at `~/.config/sws/config.json` (created on first launch):

```json
{
  "shortcut": { "key": "s", "modifiers": ["shift", "option"] },
  "command": "/usr/bin/bc",
  "args": ["-l"],
  "width": 600,
  "height": 400,
  "rememberSize": true,
  "fontFamily": "Menlo",
  "fontSize": 14,
  "logInput": false
}
```

You can also edit settings via **Preferences...** in the menu bar dropdown.

## Requirements

- macOS 13+
- Apple Silicon or Intel Mac

## License

Distributed under MIT license, see `LICENSE` for more.
