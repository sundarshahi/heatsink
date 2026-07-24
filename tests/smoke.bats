#!/usr/bin/env bats
load helpers

@test "bin/heatsink exists and is executable" {
  [ -x "$HS" ]
}

@test "heatsink with no args prints usage and exits 2" {
  run "$HS"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}
