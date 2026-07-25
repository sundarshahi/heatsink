#!/usr/bin/env bash
# Codex CLI adapter (experimental contract: {"command":...} in,
# {"decision":"allow"|"deny","reason":...} out).
# UNTESTED IN THE WILD — built to docs; file issues!
# FAIL OPEN: any problem -> allow.
set -uo pipefail

allow() { echo '{"decision":"allow"}'; exit 0; }
command -v jq >/dev/null 2>&1 || allow
input=$(cat 2>/dev/null) || allow
cmd=$(printf '%s' "$input" | jq -r '.command // ""' 2>/dev/null) || allow
[ -n "$cmd" ] || allow

a_src="$0"
while [ -h "$a_src" ]; do a_src=$(readlink "$a_src"); done
HS_BIN="$(cd "$(dirname "$a_src")/../.." && pwd)/bin/heatsink"
[ -x "$HS_BIN" ] || allow

out=$("$HS_BIN" check --command "$cmd" --json 2>/dev/null)
verdict=$(printf '%s' "$out" | jq -r '.verdict // "ok"' 2>/dev/null) || allow
reason=$(printf '%s' "$out" | jq -r '.reason // ""')
rewritten=$(printf '%s' "$out" | jq -r '.rewritten // ""')

case "$verdict" in
  deny)
    jq -n --arg r "$reason" '{decision:"deny", reason:("heatsink: " + $r)}' ;;
  throttle|warn)
    msg="heatsink: $reason"
    [ -n "$rewritten" ] && msg="$msg Prefer: $rewritten"
    jq -n --arg m "$msg" '{decision:"allow", reason:$m}' ;;
  *) echo '{"decision":"allow"}' ;;
esac
exit 0
