#!/usr/bin/env bats
load helpers

setup() {
  export HEATSINK_FAKE_CORES=10 HEATSINK_FAKE_THERMAL=ok
  export HEATSINK_FAKE_PS="$FIXTURES/ps-orphans.txt" HEATSINK_TEST_USER=dev
}

@test "check --command with missing value does not hang" {
  # MSYS bash can't set RLIMIT_CPU and says so on stderr, which `run` folds
  # into $output. The limit is a backstop against a hang, not the assertion.
  run bash -c 'ulimit -t 2 2>/dev/null; "$1" check --command' _ "$HS"
  [ "$status" -eq 0 ] || return 1
  [ "$output" = "ok" ] || return 1
}

@test "check: light command is ok even under load" {
  HEATSINK_FAKE_LOAD=99 run "$HS" check --command "git status"
  [ "$status" -eq 0 ]; [ "$output" = "ok" ] || return 1
}

@test "check: heavy command at low load is ok" {
  HEATSINK_FAKE_LOAD=2.0 run "$HS" check --command "npx vitest run"
  [ "$status" -eq 0 ]; [ "$output" = "ok" ] || return 1
}

@test "check: heavy command in throttle zone rewrites" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "npx vitest run"
  [ "$status" -eq 0 ] || return 1
  [ "$output" = "throttle: npx vitest run --maxWorkers=2" ] || return 1
}

@test "check: no-knob heavy command in throttle zone warns" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "npx tsc --noEmit"
  [ "$status" -eq 0 ]; [ "$output" = "warn" ] || return 1
}

@test "check: deny zone denies with exit 1" {
  HEATSINK_FAKE_LOAD=25 run "$HS" check --command "npx vitest run"
  [ "$status" -eq 1 ]; [ "$output" = "deny" ] || return 1
}

@test "check --json shape" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "npx vitest run" --json
  echo "$output" | jq -e '.verdict=="throttle" and .rewritten=="npx vitest run --maxWorkers=2" and .cores==10' >/dev/null
}

# Light commands skip the load read entirely (a powershell.exe spawn on
# Windows), so the field reports null rather than a made-up zero.
@test "check --json: load is null when the command is not heavy" {
  HEATSINK_FAKE_LOAD=9.5 run "$HS" check --command "git status" --json
  echo "$output" | jq -e '.verdict=="ok" and .load==null' >/dev/null
}

@test "check: thermal pressure escalates throttle zone to deny" {
  HEATSINK_FAKE_LOAD=9.5 HEATSINK_FAKE_THERMAL=pressure run "$HS" check --command "npx vitest run"
  [ "$status" -eq 1 ]; [ "$output" = "deny" ] || return 1
}

@test "wrap: runs light command and passes exit code through" {
  HEATSINK_FAKE_LOAD=1 run "$HS" wrap -- true
  [ "$status" -eq 0 ] || return 1
  HEATSINK_FAKE_LOAD=1 run "$HS" wrap -- false
  [ "$status" -eq 1 ] || return 1
}

@test "wrap: deny returns 75" {
  HEATSINK_FAKE_LOAD=25 run "$HS" wrap -- make -j8
  [ "$status" -eq 75 ] || return 1
}

@test "wrap: throttle path still classifies and rewrites a heavy command" {
  HEATSINK_FAKE_LOAD=9.5 HEATSINK_FAKE_CORES=10 run "$HS" wrap -- npx vitest run
  [[ "$output" == *"throttled"* ]] || return 1
}

@test "wrap: quoted arg with a space survives throttle rewrite unsplit" {
  HEATSINK_FAKE_LOAD=9.5 HEATSINK_FAKE_CORES=10 run "$HS" wrap -- npx vitest run --reporter "my file.txt"
  [[ "$output" == *"heatsink: throttled ->"* ]] || return 1
  [[ "$output" == *'my\ file.txt'* ]] || return 1
}

@test "doctor: reports load, burners and orphans" {
  HEATSINK_FAKE_LOAD=99 run "$HS" doctor
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *"99"* ]] || return 1
  [[ "$output" == *"yes"* ]] || return 1
  [[ "$output" == *"reap"* ]] || return 1
}

@test "reap: report-only by default, names orphans, kills nothing" {
  run "$HS" reap
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *"74586"* ]] || return 1
  [[ "$output" == *"--kill"* ]] || return 1
}

@test "reap: --dry-run always wins over --kill regardless of order" {
  run "$HS" reap --kill --dry-run
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *"report-only"* ]] || return 1
  [[ "$output" != *"SIGTERM"* ]] || return 1
}

@test "reap: --dry-run --kill (dry-run first) still wins, kills nothing" {
  run "$HS" reap --dry-run --kill
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *"report-only"* ]] || return 1
  [[ "$output" != *"SIGTERM"* ]] || return 1
}
