# Changelog

## 0.1.3 — 2026-08-01
Native Windows support (Git Bash) — the npm package no longer refuses to
install with `EBADPLATFORM`. Load comes from `ProcessorQueueLength` + busy
cores, `doctor`/`reap` scan `Win32_Process` (dead-parent processes are
reported as `ppid 1`, so orphan detection is unchanged), and `reap` uses
`taskkill`. Cygwin's `/proc/loadavg` is ignored on purpose: it exists under
Git Bash but doesn't track the Windows scheduler.

Also: commands are classified *before* load is read, so a light command
never pays for a signal it can't be judged by — on Windows that's a
`powershell.exe` spawn per hook. `check --json` now reports `"load": null`
in that case instead of a fabricated `0`.

Docs: a full usage section (every verdict, `wrap`, the hook JSON an agent
actually sees, tuning) and terminal screenshots of `doctor`/`check`/`reap`.
`make screenshots` regenerates them from the test fixtures, so they render
identically on any machine.

## 0.1.2 — 2026-07-25
`doctor`/`reap` output: truncate runaway command lines (no more full
VS Code/Firefox arg dumps), and add terminal color — heat-graded CPU%,
zone-colored load ratio, and a green/yellow/red verdict. Color is
TTY-gated and honors `NO_COLOR`; piped output stays plain.

## 0.1.1 — 2026-07-25
Fix root resolution through relative symlinks — `npx`/`npm -g` installs
symlink the bin into `node_modules/.bin`, which broke lib sourcing. CLI now
resolves its install dir correctly under npm.

## 0.1.0 — 2026-07-24
Initial release: check/wrap/doctor/reap, auto-throttle rewrite table,
claude-code plugin (tested), cursor + codex adapters (untested in the wild),
macOS + Linux, fail-open everywhere.
