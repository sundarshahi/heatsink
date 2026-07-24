# heatsink — Cursor adapter

**Status: untested in the wild.** Built to Cursor's documented hooks contract
(`beforeShellExecution`); we don't run Cursor in CI. If it misbehaves, please
open an issue with the raw hook input/output.

Wire it in `~/.cursor/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      { "command": "/absolute/path/to/heatsink/adapters/cursor/hook.sh" }
    ]
  }
}
```

Cursor has no input-rewrite channel, so in the throttle zone heatsink allows
the command but tells the agent the reduced-worker form to prefer.
