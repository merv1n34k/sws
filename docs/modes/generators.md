# Generators

Four sub-generators behind a top segmented control: **Password ·
UUID · Lorem · Random**.

## Hotkey

Default: **⌥⇧X**.

## Password

```
┌────────────────────────────────────────────────┐
│  Length   [────────●────────] 24               │
│  [✓] a-z   [✓] A-Z   [✓] 0-9   [✓] symbols     │
│                                                │
│   k9!Xb#qM2pVnTwL@8RhJsZc                       │
│                                                │
│  [ Regenerate ]                  [ Copy ]      │
└────────────────────────────────────────────────┘
```

- Length slider, 6 to 64.
- Character set toggles (any combination — at least one must be on).
- **Regenerate** picks a new password using
  `SystemRandomNumberGenerator`.
- **Copy** puts the current value on the pasteboard.
- The generator guarantees at least one character from each enabled
  set.

## UUID

- Type radio: **v4 · v7 · ULID**
- Count stepper (1 to 100).
- Output is a list of generated IDs, one per line.
- **Copy** copies the entire list.

| Type | Spec |
|---|---|
| v4 | random, RFC 4122 |
| v7 | time-ordered, draft-04 of the new RFC |
| ULID | Crockford base32, 26 chars, lexicographic-sortable |

## Lorem

- Mode radio: **words · sentences · paragraphs**
- Count stepper.
- Output text view with the generated lorem.

Pulls from a fixed dictionary so output is stable and reproducible
within a session.

## Random picker

```
┌────────────────────────────────────────────────┐
│  Items (one per line):                         │
│  ┌────────────────────────────────────────┐    │
│  │ alice                                  │    │
│  │ bob                                    │    │
│  │ charlie                                │    │
│  └────────────────────────────────────────┘    │
│  [✓] Without replacement                       │
│  [ Pick ]                                      │
│                                                │
│  Picked:  bob                                  │
│  History: bob, alice, charlie                  │
└────────────────────────────────────────────────┘
```

- Type one item per line in the input area.
- **Pick** chooses one uniformly at random.
- **Without replacement** removes picked items from future draws (the
  pool is reset when you edit the input).
- History shows recent picks.

## Configuration

No mode-specific options.

```json
{
  "id": "generators",
  "type": "generators",
  "hotkey": { "key": "g", "modifiers": ["shift", "option"] }
}
```

## Implementation pointers

- `Sources/sws/Modes/Generators/GeneratorsView.swift` — segmented control
- `Sources/sws/Modes/Generators/{Password,UUID,Lorem,Random}Section.swift`
- Tests: `Tests/swsTests/GeneratorsTests.swift` — UUID format, password
  charset coverage, lorem word counts.
