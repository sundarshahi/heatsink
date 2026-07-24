#!/usr/bin/env bats
load helpers

setup() {
  export HEATSINK_FAKE_CORES=10 HEATSINK_FAKE_THERMAL=ok
  export HEATSINK_FAKE_PS="$FIXTURES/ps-orphans.txt" HEATSINK_TEST_USER=dev
}

@test "check: light command is ok even under load" {
  HEATSINK_FAKE_LOAD=99 run "$HS" check --command "git status"
  [ "$status" -eq 0 ]; [ "$output" = "ok" ]
}

@test "check: heavy command at low load is ok" {
  HEATSINK_FAKE_LOAD=2.0 run "$HS" check --command "npx vitest run"
  [ "$status" -eq 0 ]; [ "$output" = "ok" ]
}

@test "check: heavy command in throttle zone rewrites" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "npx vitest run"
  [ "$status" -eq 0 ]
  [ "$output" = "throttle: npx vitest run --maxWorkers=2" ]
}

@test "check: no-knob heavy command in throttle zone warns" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "npx tsc --noEmit"
  [ "$status" -eq 0 ]; [ "$output" = "warn" ]
}

@test "check: deny zone denies with exit 1" {
  HEATSINK_FAKE_LOAD=25 run "$HS" check --command "npx vitest run"
  [ "$status" -eq 1 ]; [ "$output" = "deny" ]
}

@test "check --json shape" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "npx vitest run" --json
  echo "$output" | jq -e '.verdict=="throttle" and .rewritten=="npx vitest run --maxWorkers=2" and .cores==10' >/dev/null
}

@test "check: thermal pressure escalates throttle zone to deny" {
  HEATSINK_FAKE_LOAD=9.5 HEATSINK_FAKE_THERMAL=pressure run "$HS" check --command "npx vitest run"
  [ "$status" -eq 1 ]; [ "$output" = "deny" ]
}

@test "wrap: runs light command and passes exit code through" {
  HEATSINK_FAKE_LOAD=1 run "$HS" wrap -- true
  [ "$status" -eq 0 ]
  HEATSINK_FAKE_LOAD=1 run "$HS" wrap -- false
  [ "$status" -eq 1 ]
}

@test "wrap: deny returns 75" {
  HEATSINK_FAKE_LOAD=25 run "$HS" wrap -- make -j8
  [ "$status" -eq 75 ]
}

@test "doctor: reports load, burners and orphans" {
  HEATSINK_FAKE_LOAD=99 run "$HS" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"99"* ]]
  [[ "$output" == *"yes"* ]]
  [[ "$output" == *"reap"* ]]
}

@test "reap: report-only by default, names orphans, kills nothing" {
  run "$HS" reap
  [ "$status" -eq 0 ]
  [[ "$output" == *"74586"* ]]
  [[ "$output" == *"--kill"* ]]
}
