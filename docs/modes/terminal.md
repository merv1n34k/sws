# Terminal

Wraps a long-lived PTY around any command-line program. By default
binds to `/usr/bin/bc -l` (an interactive arbitrary-precision calculator),
which is why the default hotkey is **⌥⇧S**.

The terminal is built on [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
— full xterm emulation, true-color, ⌥-as-Meta enabled.

## Hotkey

Default: **⌥⇧S** (configurable).

You can add as many terminal modes as you want with different commands
— each gets its own PTY and its own hotkey.

## What you get

- The spawned program is started once, on first activation, and kept
  alive across mode switches and window hides.
- All keystrokes route to the program.
- Scrollback retained.
- Output can be mirrored to `~/.sws.log` for debugging (`logInput: true`
  at the top level of `config.json`).
- ANSI escape codes are stripped from the log file but preserved on
  screen.

## Configuration

```json
{
  "id": "calc",
  "type": "terminal",
  "hotkey": { "key": "s", "modifiers": ["shift", "option"] },
  "command": "/usr/bin/bc",
  "args": ["-l"]
}
```

| Field | Required | Default | Notes |
|---|---|---|---|
| `command` | yes | — | Absolute path to the executable |
| `args` | no | `[]` | Argument list |
| `displayName` | no | `id` capitalized | Shown in menu / status |

## Common recipes

### Python REPL

```json
{
  "id": "py", "type": "terminal",
  "hotkey": { "key": "p", "modifiers": ["shift", "option"] },
  "command": "/usr/bin/python3",
  "args": ["-q"]
}
```

### Node REPL

```json
{
  "id": "node", "type": "terminal",
  "hotkey": { "key": "n", "modifiers": ["shift", "option"] },
  "command": "/usr/local/bin/node"
}
```

### A scratch shell

```json
{
  "id": "shell", "type": "terminal",
  "hotkey": { "key": "x", "modifiers": ["shift", "option"] },
  "command": "/bin/zsh",
  "args": ["-l"]
}
```

## Font

Set globally at the top level of `config.json`:

```json
"fontFamily": "Menlo",
"fontSize": 14
```

Applies to every terminal mode.

## Caveats

- The PTY is launched once. If the program exits (e.g. you `quit` out
  of `bc`), the next activation of this mode will show a dead terminal
  until you reload sws from the menu.
- Programs that aggressively grab the alternate screen (vim, htop) work
  fine; just be aware you'll lose scrollback while they're running.
