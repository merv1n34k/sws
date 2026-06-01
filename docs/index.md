---
layout: home

hero:
  name: SWS
  text: Swift Window Shell
  tagline: A native macOS utility belt that lives behind a hotkey.
  actions:
    - theme: brand
      text: Install
      link: /guide/installation
    - theme: alt
      text: Modes
      link: /modes/terminal
    - theme: alt
      text: GitHub
      link: https://github.com/merv1n34k/sws

features:
  - title: Hotkey-first
    details: Every mode opens to its own ⌥⇧letter shortcut. All bindings are on the left half of the keyboard for one-hand reach.
  - title: Nine modes built in
    details: Terminal, Color, Time, Status, EnDe, Generators, Clipboard, OCR, Scratchpad. Each is small, focused, and discoverable.
  - title: Pinnable menu-bar widgets
    details: Live CPU / RAM / SSD / Network / IP / Wi-Fi readouts you can pin from the Status dashboard.
  - title: Native AppKit
    details: No Electron, no SwiftUI overhead — plain AppKit with system controls. Builds + runs with `swift build` and `make app`.
  - title: Polite focus
    details: When you hide the window, focus returns to the most-recently-used app, not whatever was frontmost when you originally summoned sws.
  - title: Extensible
    details: New modes drop in as one Swift file in `Modes/<name>/` plus a single registration line. The core never names a mode directly.
---

## What it looks like

| Mode | Hotkey | What it does |
|---|---|---|
| Terminal | ⌥⇧S | Any CLI (default `bc -l`); configure one terminal mode per command. |
| Color | ⌥⇧C | Pixel picker + drag-region palette + contrast checker. |
| Time | ⌥⇧Q | Stopwatch · Countdown · Pomodoro · World clocks · NLP date phrases. |
| Status | ⌥⇧D | Live system stats with pin-to-menu-bar buttons. |
| EnDe | ⌥⇧E | Base64 · URL · CSV ↔ MD · JWT · QR · Barcode. |
| Generators | ⌥⇧X | Password · UUID · Lorem · Random picker. |
| Clipboard | ⌥⇧A | Pasteboard history (configurable cap, image thumbnails). |
| OCR | ⌥⇧R | Image / PDF → text via Vision. |
| Scratchpad | ⌥⇧W | Persistent monospace text. |

See [Modes](/modes/terminal) for the per-mode reference, or jump to
[Installation](/guide/installation) to get started.
