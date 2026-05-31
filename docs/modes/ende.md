# EnDe

Encode / decode in two side-by-side panes. Edit either side; the other
updates live. Six codecs share one converter UI.

## Hotkey

Default: **⌥⇧E**.

## Layout

```
┌────────────────────────────────────────────────┐
│  Type  [ Base64 ⌄ ]                            │
├──────────────────────┬─────────────────────────┤
│  hint: plain text    │  hint: base64           │
│                      │                         │
│  Hello, world!       │  SGVsbG8sIHdvcmxkIQ==   │
│                      │                         │
└──────────────────────┴─────────────────────────┘
```

- **Type** picker switches codec.
- Each pane shows a one-line **hint** above describing what goes in it.
- Each codec ships with a sample placeholder so the field is never
  blank-and-confusing.

## Codecs

### Base64
Bidirectional. Plain UTF-8 ⇄ Base64. Accepts padded and unpadded inputs.

### URL
Bidirectional. Plain text ⇄ percent-encoded.

### CSV ↔ Markdown
Bidirectional.
- CSV → Markdown table with header row + alignment row.
- Markdown table → CSV (first row treated as headers).

Tab- and pipe-delimited inputs work too; the parser auto-sniffs.

### JWT
One-way (decode). Paste a JWT into the left pane; the right pane shows:

```
{
  "header": { "alg": "HS256", "typ": "JWT" },
  "payload": { "sub": "alice", "exp": 1735689600 }
}
```

Signature is **not verified** — this is for inspection only.

### QR
Bidirectional.
- Text on left → QR image on right (CIQRCodeGenerator, 512×512).
- Drop an image on the right → decoded text appears on the left
  (VNDetectBarcodesRequest).
- **Click the image** to copy it to the pasteboard.

### Barcode
Bidirectional, same shape as QR.
- Text → Code-128 barcode image (CICode128BarcodeGenerator).
- Image → decoded text.
- Click the image to copy.

## Common patterns

- All codecs are **bidirectional unless noted** (JWT decode-only).
- Errors render in the destination pane as a single line:
  ```
  ⚠️ invalid base64: bad padding at position 12
  ```
- Editing either pane updates the other on every keystroke (no submit
  button).

## Configuration

No mode-specific options.

```json
{
  "id": "ende",
  "type": "ende",
  "hotkey": { "key": "e", "modifiers": ["shift", "option"] }
}
```

## Adding a codec

Implement `EnDeCodec`:

```swift
protocol EnDeCodec {
    var displayName: String { get }       // "My Codec"
    var leftHint: String { get }          // "plain text"
    var rightHint: String { get }         // "encoded"
    var leftPlaceholder: String { get }
    var rightPlaceholder: String { get }
    var leftSamplePlaceholder: String? { get }
    var rightSamplePlaceholder: String? { get }

    func encode(_ left: String) -> Result<String, Error>
    func decode(_ right: String) -> Result<String, Error>?   // nil = one-way
}
```

Register it in `EnDeMode.swift` (one line per codec). For
image-output codecs (like QR), conform to `EnDeImageCodec` instead.

## Implementation pointers

- `Sources/sws/Modes/EnDe/TwoPaneConverter.swift` — shared two-pane view
- `Sources/sws/Modes/EnDe/EnDeCodec.swift` — codec protocols
- `Sources/sws/Modes/EnDe/Codecs/*.swift` — one file per codec
