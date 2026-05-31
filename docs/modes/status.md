# Status

A dashboard of system info. Click any stat to pin it as a menu-bar
widget. Click again to unpin. Pinned widgets keep ticking after sws is
hidden.

## Hotkey

Default: **⌥⇧D** (Dashboard).

## Layout

A fixed 440 × 340 window in "old phone keyboard" shape:

```
┌────────────────────────────────────────────────┐
│  IP     83.143.x.x (VPN: NordVPN)    [copy]    │
│  Wi-Fi  Home-5G   −52 dBm                       │
│                                                │
│  ┌────────┐  ┌────────┐                        │
│  │ CPU    │  │ RAM    │                        │
│  │  12%   │  │  47%   │                        │
│  └────────┘  └────────┘                        │
│  ┌────────┐  ┌────────┐                        │
│  │ SSD    │  │ Net    │                        │
│  │ 142 GB │  │ ↑0.3M  │                        │
│  │        │  │ ↓1.2M  │                        │
│  └────────┘  └────────┘                        │
└────────────────────────────────────────────────┘
```

Top: text-info reference panel (IP, Wi-Fi).
Bottom: 2-row · 2-column button grid of pinnable stats.

Pinned buttons render with a depressed appearance.

## Available stats

| Stat | Source | Update |
|---|---|---|
| **CPU** | `host_statistics64` user+sys+nice / total ticks | 1 s |
| **RAM** | `host_statistics64` (used / total pages) | 1 s |
| **SSD** | `statfs("/")` free space in GB | 30 s |
| **Network** | `getifaddrs` byte counters, delta per second | 1 s |
| **IP** | First non-loopback `getifaddrs` interface | 5 s |
| **Wi-Fi** | `CWWiFiClient` SSID + RSSI, with `networksetup -getairportnetwork en0` fallback | 5 s |

## Pinning to the menu bar

- **Click** a stat button → menu-bar widget appears.
- **Click again** → widget disappears.
- Pinned set persists to `~/.config/sws/menubar.json`; widgets respawn
  on next launch.

Menu-bar widgets render as a 2-line template image:

```
CPU
12%
```

Templates honor the OS tint, so the widget reads the same in light or
dark menu bars. Each widget polls on its own interval (see table above).

## Notes

- **Network counters** are cumulative since boot; the widget shows the
  delta since the last sample, so a brief spike or idle period flushes
  the previous reading.
- **Wi-Fi via CoreWLAN** requires Location Services on macOS Sonoma+.
  If it returns nil, sws falls back to the `networksetup` CLI; if both
  fail, the readout shows `—`.

## Configuration

No mode-specific options.

```json
{
  "id": "status",
  "type": "status",
  "hotkey": { "key": "d", "modifiers": ["shift", "option"] }
}
```

The pinned-widget set is stored separately in `menubar.json`, not in
`config.json`.

## Implementation pointers

- `Sources/sws/Modes/Status/StatusView.swift` — fixed-size phone-keyboard layout
- `Sources/sws/Modes/Status/StatusWidgets.swift` — all six widget implementations
- `Sources/sws/MenuBar/MenuBarWidget.swift` — protocol + `MenuBarRendering.twoLines`
- `Sources/sws/MenuBar/MenuBarWidgetRegistry.swift` — pin persistence + status item lifecycle
