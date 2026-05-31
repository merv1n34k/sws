# Color

Single unified window: picker readout · palette extractor · contrast
checker · recent history.

## Hotkey

Default: **⌥⇧C**.

## Layout

```
┌────────────────────────────────────────────────┐
│  [SWATCH]   HEX  #1A1B26              [copy]   │
│             RGB  rgb(...)             [copy]   │
│             HSL  hsl(...)             [copy]   │
│             HSB  hsb(...)             [copy]   │
├────────────────────────────────────────────────┤
│  Palette  ▕█▕█▕█▕█▕█▕█▕█▕█▏  [copy CSV]        │
│  [ Extract palette from screen region ]        │
├────────────────────────────────────────────────┤
│  Contrast  [ColorWell A] vs [ColorWell B]      │
│    14.8 : 1   AA ✓  AA-L ✓  AAA ✓               │
├────────────────────────────────────────────────┤
│  Recent  ▕▢▕▢▕▢▕▢▕▢▕▢▕▢▕▢▏                    │
└────────────────────────────────────────────────┘
```

## Picker

While the Color mode window is visible, the screen-picker overlay is
always armed.

- **Click** anywhere on screen → pixel under the cursor becomes the
  selected color. Readouts and the swatch update.
- **Drag a rectangle** → palette extraction (see next section).
- Picked color is automatically appended to **Recent** (last 16).

The picker uses `CGDisplayCreateImage` of the full display, so it sees
**windows of other apps**, not just the wallpaper. This requires
**Screen Recording** permission — see [Installation](/guide/installation).

## Readouts

For the currently selected color, six formats are shown with one-click
copy:

| Label | Example |
|---|---|
| HEX | `#1A1B26` |
| RGB | `rgb(26, 27, 38)` |
| HSL | `hsl(235, 19%, 13%)` |
| HSB | `hsb(235, 32%, 15%)` |
| Oklab | `oklab(0.146 -0.005 -0.024)` |
| Swatch | The color itself, drag-out as `NSColor` |

## Palette extraction

Two ways to feed an image in:

1. **Drag-and-drop** any image file onto the palette strip.
2. **Click "Extract palette from screen region"** → drag a rectangle
   on screen → palette built from that region's pixels.

Algorithm:

- Pixels are converted into **Oklab** color space (perceptually
  uniform; clusters match how humans group colors).
- **k-means++** with k=8 produces the palette.
- Result is sorted by lightness.
- **[copy CSV]** copies `#aabbcc,#ddeeff,…` for pasting into design
  tools.

## Contrast checker

Two `NSColorWell`s. Pick foreground + background. Below them:

- **Ratio** — WCAG 2.x relative luminance contrast ratio (1:1 to 21:1).
- **AA** — passes 4.5:1 (regular text)?
- **AA-Large** — passes 3:1 (≥18pt or ≥14pt bold)?
- **AAA** — passes 7:1?

Pass is rendered in **green**, fail in **red** — color-coded so the
verdict is unambiguous.

## Recent colors

Last 16 picked colors as a clickable strip at the bottom.
- **Click** an entry to reload it as the selected color.

## Configuration

No mode-specific options yet. Just the standard entry:

```json
{
  "id": "color",
  "type": "color",
  "hotkey": { "key": "c", "modifiers": ["shift", "option"] }
}
```

## Implementation pointers

- `Sources/sws/Modes/Color/ColorView.swift` — root view, six readout rows
- `Sources/sws/Modes/Color/PaletteExtractor.swift` — Oklab + k-means++
- `Sources/sws/Modes/Color/ContrastSection.swift` — WCAG ratio + verdict
- `Sources/sws/Modes/Color/PickerOverlay.swift` — always-on click/drag layer
