#!/usr/bin/env bats
load helpers

@test "bin/heatsink exists and is executable" {
  [ -x "$HS" ] || return 1
}

# Real-machine scan, no fixture: on Windows this is the only test that runs
# hs_win_ps, and it fails loudly if the emitted columns stop parsing.
@test "hs_ps returns parseable rows for the real machine" {
  . "$HS_REPO/lib/procs.sh"
  run hs_top_burners 3
  [ -n "$output" ] || return 1
  echo "$output" | awk 'NF<6 || $1 !~ /^[0-9]+$/ { exit 1 }'
}

@test "heatsink with no args prints usage and exits 2" {
  run "$HS"
  [ "$status" -eq 2 ] || return 1
  [[ "$output" == *"usage:"* ]] || return 1
}
