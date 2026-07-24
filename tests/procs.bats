#!/usr/bin/env bats
load helpers

setup() {
  . "$HS_REPO/lib/procs.sh"
  export HEATSINK_FAKE_PS="$FIXTURES/ps-orphans.txt"
  export HEATSINK_TEST_USER=dev
}

@test "top burners sorted by cpu, no header" {
  run hs_top_burners 3
  [[ "${lines[0]}" == *lowpid_burner* ]] || return 1
  [[ "$output" != *"%CPU"* ]] || return 1
}

@test "orphans: burner-profile yes procs found" {
  run hs_orphans
  [[ "$output" == *"74586"* ]] || return 1
  [[ "$output" == *"74587"* ]] || return 1
}

@test "orphans: generic runaway (>90% cpu, >1h, ppid 1) found" {
  run hs_orphans
  [[ "$output" == *"91001"* ]] || return 1
}

@test "orphans: young high-cpu proc NOT flagged" {
  run hs_orphans
  [[ "$output" != *"91002"* ]] || return 1
}

@test "orphans: denylist (WindowServer), other users, pid<100, non-orphans, idle excluded" {
  run hs_orphans
  [[ "$output" != *WindowServer* ]] || return 1
  [[ "$output" != *"99001"* ]] || return 1   # other user
  [[ "$output" != *"   85"* && "$output" != *lowpid_burner* ]] || return 1  # pid < 100
  [[ "$output" != *"62652"* ]] || return 1   # ppid != 1 (live vitest)
  [[ "$output" != *"99002"* ]] || return 1   # long-lived but idle
}

@test "adversarial: root-owned yes, substring near-misses, sub-1h, and 90.0 boundary excluded" {
  HEATSINK_FAKE_PS="$FIXTURES/ps-adversarial.txt" run hs_orphans
  [[ "$output" != *"30001"* ]] || return 1  # root's yes — not our user
  [[ "$output" != *"30002"* ]] || return 1  # kyes — substring, not the yes binary
  [[ "$output" != *"30003"* ]] || return 1  # analyses.rb — substring, not the yes binary
  [[ "$output" != *"30004"* ]] || return 1  # /home/yes/ — path component, not binary
  [[ "$output" != *"30005"* ]] || return 1  # 59:59 = under 1h
  [[ "$output" != *"30006"* ]] || return 1  # exactly 90.0 — strict >90
}

@test "adversarial: >90% for >1h generic runaway still caught" {
  HEATSINK_FAKE_PS="$FIXTURES/ps-adversarial.txt" run hs_orphans
  [[ "$output" == *"30007"* ]] || return 1
}

# Positive control for the name gate: the substring near-misses above are all
# LOW-cpu on purpose, so they can only be flagged by the burner profile. This
# proves the profile still fires on the real `yes` binary at the same low cpu —
# otherwise the exclusions above would pass for the wrong reason.
@test "adversarial: real yes binary is caught by burner profile even at low cpu" {
  HEATSINK_FAKE_PS="$FIXTURES/ps-adversarial.txt" run hs_orphans
  [[ "$output" == *"30008"* ]] || return 1
}
