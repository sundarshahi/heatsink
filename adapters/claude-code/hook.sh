#!/usr/bin/env bash
# Claude Code PreToolUse (matcher: Bash) adapter.
# FAIL OPEN: any problem -> silent exit 0. A guard must never wedge the agent.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null) || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

a_src="$0"
while [ -h "$a_src" ]; do a_src=$(readlink "$a_src"); done
HS_BIN="$(cd "$(dirname "$a_src")/../.." && pwd)/bin/heatsink"
[ -x "$HS_BIN" ] || exit 0

out=$("$HS_BIN" check --command "$cmd" --json 2>/dev/null)
verdict=$(printf '%s' "$out" | jq -r '.verdict // "ok"' 2>/dev/null) || exit 0
[ -n "$verdict" ] || exit 0
load=$(printf '%s' "$out" | jq -r '.load');   cores=$(printf '%s' "$out" | jq -r '.cores')
reason=$(printf '%s' "$out" | jq -r '.reason // ""')
rewritten=$(printf '%s' "$out" | jq -r '.rewritten // ""')

case "$verdict" in
  deny)
    jq -n --arg r "$reason" --arg l "$load" --arg c "$cores" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("heatsink: " + $r + " Check with: heatsink doctor")
      },
      systemMessage: ("heatsink: blocked a heavy command (load " + $l + " on " + $c + " cores)")
    }' ;;
  throttle)
    [ -n "$rewritten" ] || exit 0
    jq -n --arg cmd "$rewritten" --arg r "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        updatedInput: { command: $cmd }
      },
      systemMessage: ("heatsink: " + $r + " -> " + $cmd)
    }' ;;
  warn)
    jq -n --arg r "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("heatsink: " + $r + " Do not start other heavy jobs alongside this one.")
      },
      systemMessage: ("heatsink: " + $r)
    }' ;;
  *) exit 0 ;;
esac
exit 0
