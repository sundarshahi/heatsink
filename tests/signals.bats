#!/usr/bin/env bats
load helpers

setup() { . "$HS_REPO/lib/signals.sh"; }

@test "hs_load1 honors HEATSINK_FAKE_LOAD" {
  HEATSINK_FAKE_LOAD=42.5 run hs_load1
  [ "$output" = "42.5" ]
}

@test "hs_load1 returns a number on the real machine" {
  run hs_load1
  [[ "$output" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

@test "hs_cores honors HEATSINK_FAKE_CORES" {
  HEATSINK_FAKE_CORES=10 run hs_cores
  [ "$output" = "10" ]
}

@test "hs_cores returns a positive int on the real machine" {
  run hs_cores
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$output" -gt 0 ]
}

@test "hs_thermal honors HEATSINK_FAKE_THERMAL" {
  HEATSINK_FAKE_THERMAL=pressure run hs_thermal
  [ "$output" = "pressure" ]
}

@test "hs_thermal returns ok or pressure on the real machine" {
  run hs_thermal
  [[ "$output" = "ok" || "$output" = "pressure" ]]
}
