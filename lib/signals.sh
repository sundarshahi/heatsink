#!/usr/bin/env bash
# Machine signals. Every reader honors a HEATSINK_FAKE_* override so the
# test suite never depends on the runner's real load.

hs_load1() {
  if [ -n "${HEATSINK_FAKE_LOAD:-}" ]; then printf '%s\n' "$HEATSINK_FAKE_LOAD"; return 0; fi
  if [ -r /proc/loadavg ]; then awk '{print $1}' /proc/loadavg; return 0; fi
  # macOS: "{ 2.92 13.76 34.45 }"
  sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}'
}

hs_cores() {
  if [ -n "${HEATSINK_FAKE_CORES:-}" ]; then printf '%s\n' "$HEATSINK_FAKE_CORES"; return 0; fi
  sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 0
}

# "pressure" when the OS says it is throttling; else "ok".
# Linux: any thermal zone >= 85C (millidegrees, root-free).
# macOS: pmset -g therm CPU_Speed_Limit < 100. NO powermetrics (needs sudo).
hs_thermal() {
  if [ -n "${HEATSINK_FAKE_THERMAL:-}" ]; then printf '%s\n' "$HEATSINK_FAKE_THERMAL"; return 0; fi
  local f t lim
  if ls /sys/class/thermal/thermal_zone*/temp >/dev/null 2>&1; then
    for f in /sys/class/thermal/thermal_zone*/temp; do
      t=$(cat "$f" 2>/dev/null) || continue
      case "$t" in ''|*[!0-9]*) continue ;; esac
      if [ "$t" -ge 85000 ]; then echo pressure; return 0; fi
    done
    echo ok; return 0
  fi
  lim=$(pmset -g therm 2>/dev/null | awk -F= '/CPU_Speed_Limit/ {gsub(/[[:space:]]/,"",$2); print $2}')
  case "$lim" in ''|*[!0-9]*) echo ok; return 0 ;; esac
  if [ "$lim" -lt 100 ]; then echo pressure; else echo ok; fi
}
