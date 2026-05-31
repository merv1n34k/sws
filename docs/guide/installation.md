# Installation

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel
- Xcode command-line tools (provides `swift`, `codesign`, `iconutil`)

```bash
xcode-select --install   # if not already installed
```

## Build & install

```bash
git clone https://github.com/merv1n34k/sws.git
cd sws
make install
```

`make install` does, in order:

1. Builds the release binary with `swift build -c release` (cached — no rebuild if sources are unchanged).
2. Generates the app icon (`scripts/generate-icon.swift` → `AppIcon.icns`).
3. Wraps the binary in `SWS.app` with Info.plist and an ad-hoc code signature.
4. Copies `SWS.app` to `/Applications/` (replacing any prior copy).
5. Strips the `com.apple.quarantine` extended attribute so Gatekeeper doesn't translocate it.
6. Resets the TCC Screen Recording grant for `com.merv1n34k.sws`, so the new build's identity is what TCC remembers on first launch.

## First launch

```bash
open /Applications/SWS.app
```

The Color and OCR modes need Screen Recording permission. macOS will
prompt on launch (or on first use). Grant it under **System Settings →
Privacy & Security → Screen Recording**, then **quit and reopen sws** —
TCC permissions only take effect after a relaunch.

If the prompt doesn't appear (sometimes happens with ad-hoc-signed
binaries), open System Settings yourself, click the `+` under Screen
Recording, and add `/Applications/SWS.app`.

## Make targets

| Target | Purpose |
|---|---|
| `make setup` | `swift package resolve` |
| `make dev` | Debug build + run from `.build/debug/sws` |
| `make build` | Release build |
| `make test` | `swift test` |
| `make lint` | SwiftLint if installed (no-op otherwise) |
| `make fmt` | swift-format if installed |
| `make icon` | Build `.build/AppIcon.icns` |
| `make app` | Build `.build/SWS.app` (idempotent — skips if inputs unchanged) |
| `make install` | Build app, copy to `/Applications`, reset TCC |
| `make uninstall` | Remove `/Applications/SWS.app` |
| `make clean` | `swift package clean` + remove `.build/` |

## Updating

```bash
git pull
make install
```

The build skips itself when no source changed, so re-running `make
install` after a `git pull` only rebuilds what actually moved.

## Uninstall

```bash
make uninstall
tccutil reset ScreenCapture com.merv1n34k.sws
rm -rf ~/.config/sws
```

The last two lines also wipe TCC grants and any persistent state
(clipboard history, scratchpad, pinned widgets, user config).
