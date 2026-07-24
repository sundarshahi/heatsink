# heatsink — Codex adapter

**Status: experimental & untested in the wild.** Codex's hook surface is not
stable; this adapter speaks a minimal contract — stdin `{"command": "..."}`,
stdout `{"decision":"allow"|"deny","reason":"..."}` — suitable for wrapper
integrations. If you wire it into a real Codex setup, open an issue and tell
us what the harness actually sends.

Alternative that works everywhere: `heatsink wrap -- <cmd>` (see
`adapters/generic/README.md`).
