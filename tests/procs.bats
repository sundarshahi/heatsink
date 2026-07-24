#!/usr/bin/env bats
load helpers

setup() {
  . "$HS_REPO/lib/procs.sh"
  export HEATSINK_FAKE_PS="$FIXTURES/ps-orphans.txt"
  export HEATSINK_TEST_USER=dev
}

@test "top burners sorted by cpu, no header" {
  run hs_top_burners 3
  [[ "${lines[0]}" == *lowpid_burner* ]]
  [[ "$output" != *"%CPU"* ]]
}

@test "orphans: burner-profile yes procs found" {
  run hs_orphans
  [[ "$output" == *"74586"* ]]
  [[ "$output" == *"74587"* ]]
}

@test "orphans: generic runaway (>90% cpu, >1h, ppid 1) found" {
  run hs_orphans
  [[ "$output" == *"91001"* ]]
}

@test "orphans: young high-cpu proc NOT flagged" {
  run hs_orphans
  [[ "$output" != *"91002"* ]]
}

@test "orphans: denylist (WindowServer), other users, pid<100, non-orphans, idle excluded" {
  run hs_orphans
  [[ "$output" != *WindowServer* ]]
  [[ "$output" != *"99001"* ]]   # other user
  [[ "$output" != *"   85"* && "$output" != *lowpid_burner* ]]  # pid < 100
  [[ "$output" != *"62652"* ]]   # ppid != 1 (live vitest)
  [[ "$output" != *"99002"* ]]   # long-lived but idle
}
