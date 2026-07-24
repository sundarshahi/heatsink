#!/usr/bin/env bats
load helpers

setup() { export HEATSINK_FAKE_CORES=10 HEATSINK_FAKE_THERMAL=ok; }

@test "cursor: ok -> permission allow" {
  export HEATSINK_FAKE_LOAD=1
  run bash -c 'echo "{\"command\":\"npx vitest run\"}" | "$1"' _ "$HS_REPO/adapters/cursor/hook.sh"
  [ "$status" -eq 0 ] || return 1
  echo "$output" | jq -e '.permission=="allow"' >/dev/null
}

@test "cursor: deny zone -> permission deny with messages" {
  export HEATSINK_FAKE_LOAD=25
  run bash -c 'echo "{\"command\":\"make -j8\"}" | "$1"' _ "$HS_REPO/adapters/cursor/hook.sh"
  echo "$output" | jq -e '.permission=="deny" and (.userMessage|length)>0 and (.agentMessage|length)>0' >/dev/null
}

@test "cursor: throttle zone -> allow but agentMessage carries rewritten form" {
  export HEATSINK_FAKE_LOAD=9.5
  run bash -c 'echo "{\"command\":\"npx vitest run\"}" | "$1"' _ "$HS_REPO/adapters/cursor/hook.sh"
  echo "$output" | jq -e '.permission=="allow" and (.agentMessage|contains("--maxWorkers=2"))' >/dev/null
}

@test "codex: deny zone -> decision deny" {
  export HEATSINK_FAKE_LOAD=25
  run bash -c 'echo "{\"command\":\"make -j8\"}" | "$1"' _ "$HS_REPO/adapters/codex/hook.sh"
  echo "$output" | jq -e '.decision=="deny" and (.reason|length)>0' >/dev/null
}

@test "codex: ok -> decision allow" {
  export HEATSINK_FAKE_LOAD=1
  run bash -c 'echo "{\"command\":\"git status\"}" | "$1"' _ "$HS_REPO/adapters/codex/hook.sh"
  echo "$output" | jq -e '.decision=="allow"' >/dev/null
}

@test "both fail open on garbage stdin" {
  run bash -c 'echo garbage | "$1"' _ "$HS_REPO/adapters/cursor/hook.sh"
  [ "$status" -eq 0 ] || return 1
  run bash -c 'echo garbage | "$1"' _ "$HS_REPO/adapters/codex/hook.sh"
  [ "$status" -eq 0 ] || return 1
}
