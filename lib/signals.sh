#!/usr/bin/env bash
# Machine signals. Every reader honors a HEATSINK_FAKE_* override so the
# test suite never depends on the runner's real load.

# shellcheck source=lib/win.sh
. "${BASH_SOURCE[0]%/*}/win.sh"

hs_load1() {
  if [ -n "${HEATSINK_FAKE_LOAD:-}" ]; then printf '%s\n' "$HEATSINK_FAKE_LOAD"; return 0; fi
  # Windows first: Cygwin/MSYS expose a /proc/loadavg that does not track
  # Windows' own scheduler, so reading it there would silently report calm.
  if hs_is_windows; then hs_win_load; return 0; fi
  if [ -r /proc/loadavg ]; then awk '{print $1}' /proc/loadavg; return 0; fi
  # macOS: "{ 2.92 13.76 34.45 }"
  sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}'
}

hs_cores() {
  if [ -n "${HEATSINK_FAKE_CORES:-}" ]; then printf '%s\n' "$HEATSINK_FAKE_CORES"; return 0; fi
  if hs_is_windows && [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
    printf '%s\n' "$NUMBER_OF_PROCESSORS"; return 0
  fi
  sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 0
}

# "pressure" when the OS says it is throttling; else "ok".
# Linux: any thermal zone >= 85C (millidegrees, root-free).
# macOS: pmset -g therm CPU_Speed_Limit < 100. NO powermetrics (needs sudo).
# Windows: nothing root-free and vendor-neutral exists (MSAcpi_ThermalZone-
# Temperature is unimplemented on most laptops), so load governs alone — the
# same tradeoff macOS already makes. See README "Why no temperature".
hs_thermal() {
  if [ -n "${HEATSINK_FAKE_THERMAL:-}" ]; then printf '%s\n' "$HEATSINK_FAKE_THERMAL"; return 0; fi
  if hs_is_windows; then echo ok; return 0; fi
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
