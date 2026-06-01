# Time

Five time-related sub-modes behind a top segmented control.

## Hotkey

Default: **⌥⇧Q**.

## Sub-modes

| Tab | Purpose |
|---|---|
| Stopwatch | Up-counting timer with lap recording |
| Countdown | Type-a-number-and-Enter timer |
| Pomodoro | Cyclic work/break with phase notifications |
| World | Multiple clocks side-by-side |
| When-is | Natural-language date phrase → resolved date + live countdown |

The segmented control sits at the top; the active sub-mode is recorded
in `defaultSubMode` and used on next launch.

## Stopwatch

- Start / Pause / Reset.
- **Lap** captures the current elapsed time into a list below.
- Resolution: 10 ms display, monotonic clock under the hood
  (`CFAbsoluteTimeGetCurrent`).

## Countdown

- Type a number → press **Enter** → starts counting down.
- Input accepts shorthand: `90s`, `5m`, `1h`, `25` (assumes minutes if
  no unit, treats `25m` and `1500s` the same).
- Macro buttons for common durations (1m / 5m / 10m / 25m / 1h).
- Notification + sound when it reaches zero.

## Pomodoro

Phase-based cyclic timer with per-phase notifications.

| Phase | Default |
|---|---|
| Work | 25 min (`pomodoroWorkMinutes`) |
| Break | 5 min (`pomodoroBreakMinutes`) |

UI:

- Big phase label + remaining time
- Start / Pause / **Skip phase** (advances to next phase immediately)
- Cycle counter (how many work phases finished this session)

## World

Multiple clocks side-by-side. Config feeds the list:

```json
"worldClocks": ["UTC+0", "UTC+3", "America/New_York", "Europe/Berlin"]
```

Accepts either `UTC±N` offsets or IANA zone IDs.

Each clock shows the current time + the offset relative to your local
time. Refreshes once a second.

## When-is

Single text field. Type a phrase, get a resolved date and a live
countdown to it.

Supported phrases:

- `20 hours from now`
- `3 weekdays from monday`
- `next saturday` (Saturday in the same week if today isn't already
  Saturday; otherwise next Saturday)
- `tomorrow at 3pm`
- `friday 18:00`
- `in 2 weeks`
- Any phrase `NSDataDetector(.date)` recognizes

Output:

```
Resolved:  Wed, 3 Jun 2026 at 15:00 (+3h 22m)
In:        3 hours 22 minutes
```

Updates live so you can see the countdown tick.

## Configuration

```json
{
  "id": "timer",
  "type": "timer",
  "hotkey": { "key": "t", "modifiers": ["shift", "option"] },
  "defaultSubMode": "countdown",
  "worldClocks": ["UTC+0", "America/New_York"],
  "pomodoroWorkMinutes": 25,
  "pomodoroBreakMinutes": 5
}
```

| Field | Default | Notes |
|---|---|---|
| `defaultSubMode` | `"stopwatch"` | One of `stopwatch` / `countdown` / `pomodoro` / `world` / `whenis` |
| `worldClocks` | `["UTC+0"]` | Used only by World sub-mode |
| `pomodoroWorkMinutes` | `25` | Used only by Pomodoro |
| `pomodoroBreakMinutes` | `5` | Used only by Pomodoro |

## Implementation pointers

- `Sources/sws/Modes/Timer/TimerView.swift` — segmented control + sub-view swap
- `Sources/sws/Modes/Timer/{Stopwatch,Countdown,Pomodoro,WorldClock,WhenIs}Section.swift`
- `Sources/sws/Modes/Timer/DatePhraseParser.swift` — `NSDataDetector` + custom fallbacks
