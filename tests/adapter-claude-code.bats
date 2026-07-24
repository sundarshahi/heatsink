#!/usr/bin/env bats
load helpers

HOOK() { "$HS_REPO/adapters/claude-code/hook.sh"; }

payload() {  # $1 = command
  jq -n --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}'
}

setup() { export HEATSINK_FAKE_CORES=10 HEATSINK_FAKE_THERMAL=ok; }

@test "ok verdict: silent, exit 0" {
  export HEATSINK_FAKE_LOAD=1
  run bash -c 'echo "$1" | "$2"' _ "$(payload 'npx vitest run')" "$HS_REPO/adapters/claude-code/hook.sh"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "light command: silent even at high load" {
  export HEATSINK_FAKE_LOAD=99
  run bash -c 'echo "$1" | "$2"' _ "$(payload 'git status')" "$HS_REPO/adapters/claude-code/hook.sh"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "throttle: emits updatedInput with rewritten command" {
  export HEATSINK_FAKE_LOAD=9.5
  run bash -c 'echo "$1" | "$2"' _ "$(payload 'npx vitest run')" "$HS_REPO/adapters/claude-code/hook.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName=="PreToolUse"
    and .hookSpecificOutput.updatedInput.command=="npx vitest run --maxWorkers=2"
    and (.systemMessage|length)>0' >/dev/null
}

@test "warn: emits additionalContext" {
  export HEATSINK_FAKE_LOAD=9.5
  run bash -c 'echo "$1" | "$2"' _ "$(payload 'npx tsc --noEmit')" "$HS_REPO/adapters/claude-code/hook.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '(.hookSpecificOutput.additionalContext|length)>0' >/dev/null
}

@test "deny: emits permissionDecision deny + reason, still exit 0" {
  export HEATSINK_FAKE_LOAD=25
  run bash -c 'echo "$1" | "$2"' _ "$(payload 'make -j8')" "$HS_REPO/adapters/claude-code/hook.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision=="deny"
    and (.hookSpecificOutput.permissionDecisionReason|length)>0' >/dev/null
}

@test "fail open: garbage stdin -> silent exit 0" {
  run bash -c 'echo "not json" | "$1"' _ "$HS_REPO/adapters/claude-code/hook.sh"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}
