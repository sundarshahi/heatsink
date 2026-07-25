# Changelog

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
