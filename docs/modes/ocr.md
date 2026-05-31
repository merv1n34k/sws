# OCR

Extract text from images, PDFs, or screen regions. Uses Apple's Vision
framework — fully on-device, no network calls.

## Hotkey

Default: **⌥⇧R** (Recognize).

## Layout

```
┌────────────────────────────────────────────────┐
│  ┌────────────────────────────────────────┐    │
│  │  Drop image or PDF here                │    │
│  │  • paste from clipboard                │    │
│  │  • [ Pick screen region ]              │    │
│  │  • [ Browse… ]                         │    │
│  └────────────────────────────────────────┘    │
│  Language  [ Auto ⌄ ]                          │
├────────────────────────────────────────────────┤
│  (extracted text, scrollable, selectable)      │
│                                                │
│                              [ Copy all ]      │
└────────────────────────────────────────────────┘
```

## Inputs

Four ways to feed it:

1. **Drag & drop** an image or PDF onto the drop zone.
2. **Paste from clipboard** — accepts text-bearing image data.
3. **Pick screen region** — drag a rectangle on screen; that region is
   captured via `CGDisplayCreateImage` and OCR'd.
4. **Browse…** — file picker for `.png`, `.jpg`, `.jpeg`, `.tiff`,
   `.heic`, `.pdf`.

PDFs are rasterized page-by-page via `PDFKit` and OCR'd one page at a
time; results are joined with `--- page N ---` separators.

## Language picker

| Option | Behavior |
|---|---|
| Auto | Uses `VNRecognizeTextRequest`'s default language model |
| Specific languages | Hints to Vision (English, French, German, Spanish, Italian, Portuguese, Chinese Simplified, Chinese Traditional, Japanese, Korean) |

Vision's text recognition is fast (`.accurate` recognition level)
and runs entirely on-device.

## Output

The extracted text appears in the scrollable area below.

- Multi-line preserves the recognized line breaks.
- **Copy all** copies the entire extracted text.
- Selectable / copyable per-block for partial copy.

## Permissions

"Pick screen region" requires **Screen Recording** permission. See
[Installation](/guide/installation#first-launch).

## Configuration

No mode-specific options.

```json
{
  "id": "ocr",
  "type": "ocr",
  "hotkey": { "key": "r", "modifiers": ["shift", "option"] }
}
```

## Implementation pointers

- `Sources/sws/Modes/OCR/OCRPipeline.swift` — Vision request + PDF rasterizer
- `Sources/sws/Modes/OCR/OCRView.swift` — drop zone + result area
- `Sources/sws/Modes/OCR/OCRMode.swift` — mode lifecycle wiring
