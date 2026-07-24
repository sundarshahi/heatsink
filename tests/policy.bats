#!/usr/bin/env bats
load helpers

setup() { . "$HS_REPO/lib/policy.sh"; }

@test "level 0 below throttle ratio" {
  run hs_level 4.0 10 ok
  [ "$output" = "0" ]
}

@test "level 1 at 0.9x cores (default throttle ratio)" {
  run hs_level 9.0 10 ok
  [ "$output" = "1" ]
}

@test "level 2 at 2.0x cores (default deny ratio)" {
  run hs_level 20.0 10 ok
  [ "$output" = "2" ]
}

@test "thermal pressure escalates 1 -> 2" {
  run hs_level 9.0 10 pressure
  [ "$output" = "2" ]
}

@test "thermal pressure leaves 0 alone" {
  run hs_level 1.0 10 pressure
  [ "$output" = "0" ]
}

@test "ratios are tunable via env" {
  HEATSINK_THROTTLE_RATIO=0.5 run hs_level 6.0 10 ok
  [ "$output" = "1" ]
  HEATSINK_DENY_RATIO=0.5 run hs_level 6.0 10 ok
  [ "$output" = "2" ]
}

@test "zero cores fails open to level 0" {
  run hs_level 99 0 ok
  [ "$output" = "0" ]
}

@test "non-numeric load fails open to level 0" {
  run hs_level banana 10 ok
  [ "$output" = "0" ]
}

@test "target workers: cores/4 with floor of HEATSINK_MIN_WORKERS" {
  run hs_target_workers 16
  [ "$output" = "4" ]
  run hs_target_workers 10
  [ "$output" = "2" ]
  HEATSINK_MIN_WORKERS=3 run hs_target_workers 4
  [ "$output" = "3" ]
}
