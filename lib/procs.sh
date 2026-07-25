#!/usr/bin/env bash
# Process scanning: burners + reap-safe orphans.

HS_BURNER_PROFILE='(^|/)(yes|stress|stress-ng)( |$)|dd if=/dev/zero|cat /dev/urandom'
HS_REAP_DENYLIST='launchd|WindowServer|loginwindow|kernel_task|systemd|/System/|/usr/libexec/|sshd'

hs_ps() {
  if [ -n "${HEATSINK_FAKE_PS:-}" ]; then cat "$HEATSINK_FAKE_PS"; return 0; fi
  ps -Ao pid,ppid,user,%cpu,etime,command
}

hs_top_burners() {
  hs_ps | awk 'NR>1' | sort -k4 -rn | head -"${1:-8}"
}

# ETIME >= 1h: has hours (HH:MM:SS) or days (DD-HH:MM:SS).
hs__etime_over_1h() {
  case "$1" in
    *-*) return 0 ;;
    *:*:*) return 0 ;;
    *) return 1 ;;
  esac
}

# Candidates: own user, ppid==1, pid>=100, not denylisted, and either a known
# burner profile OR >90% cpu sustained >1h. Output: PID %CPU ETIME COMMAND...
hs_orphans() {
  local me="${HEATSINK_TEST_USER:-${USER:-$(id -un)}}"
  hs_ps | awk 'NR>1 && $2==1' | while read -r pid _ user cpu etime rest; do
    [ "$user" = "$me" ] || continue
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    [ "$pid" -ge 100 ] || continue
    printf '%s' "$rest" | grep -Eq "$HS_REAP_DENYLIST" && continue
    if printf '%s' "$rest" | grep -Eq "$HS_BURNER_PROFILE"; then
      printf '%s %s %s %s\n' "$pid" "$cpu" "$etime" "$rest"
      continue
    fi
    hs__etime_over_1h "$etime" || continue
    awk -v c="$cpu" 'BEGIN { exit (c > 90) ? 0 : 1 }' || continue
    printf '%s %s %s %s\n' "$pid" "$cpu" "$etime" "$rest"
  done
}
