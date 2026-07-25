#!/usr/bin/env bash
# Cursor beforeShellExecution hook adapter.
# UNTESTED IN THE WILD: built to Cursor's documented hook contract; file issues!
# FAIL OPEN: any problem -> {"permission":"allow"} or silence.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null) || exit 0
cmd=$(printf '%s' "$input" | jq -r '.command // ""' 2>/dev/null) || exit 0
[ -n "$cmd" ] || { echo '{"permission":"allow"}'; exit 0; }

a_src="$0"
while [ -h "$a_src" ]; do a_src=$(readlink "$a_src"); done
HS_BIN="$(cd "$(dirname "$a_src")/../.." && pwd)/bin/heatsink"
[ -x "$HS_BIN" ] || { echo '{"permission":"allow"}'; exit 0; }

out=$("$HS_BIN" check --command "$cmd" --json 2>/dev/null)
verdict=$(printf '%s' "$out" | jq -r '.verdict // "ok"' 2>/dev/null) || { echo '{"permission":"allow"}'; exit 0; }
reason=$(printf '%s' "$out" | jq -r '.reason // ""')
rewritten=$(printf '%s' "$out" | jq -r '.rewritten // ""')

case "$verdict" in
  deny)
    jq -n --arg r "$reason" '{permission:"deny",
      userMessage:("heatsink: " + $r),
      agentMessage:("heatsink blocked this: " + $r + " Retry later or with reduced parallelism.")}' ;;
  throttle)
    # Cursor has no input-rewrite channel: allow, but tell the agent the cooler form.
    jq -n --arg r "$reason" --arg c "$rewritten" '{permission:"allow",
      agentMessage:("heatsink: " + $r + " Prefer running: " + $c)}' ;;
  warn)
    jq -n --arg r "$reason" '{permission:"allow", agentMessage:("heatsink: " + $r)}' ;;
  *)
    echo '{"permission":"allow"}' ;;
esac
exit 0
