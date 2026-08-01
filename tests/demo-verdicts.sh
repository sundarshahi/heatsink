#!/usr/bin/env bash
# Scripted terminal session for docs/img/check.png (see `make screenshots`).
# Load is faked so the four verdicts render the same on any machine.
export HEATSINK_FAKE_CORES="${HEATSINK_FAKE_CORES:-10}"

run() { printf '$ %s\n' "$2"; HEATSINK_FAKE_LOAD="$1" bash -c "$2"; echo; }

run 1.2  'heatsink check --command "npx vitest run"'
run 9.5  'heatsink check --command "npx vitest run" --json'
run 9.5  'heatsink check --command "make -j 16"'
run 9.5  'heatsink check --command "tsc -b"'
run 21.4 'heatsink check --command "cargo build"'
