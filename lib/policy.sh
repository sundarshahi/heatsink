#!/usr/bin/env bash
# Pure policy: signals in, level out. No I/O — fully unit-testable.

# hs_level LOAD1 CORES THERMAL -> 0 ok | 1 throttle zone | 2 deny zone
# Fails open to 0 on any non-numeric input or zero cores.
hs_level() {
  local load="$1" cores="$2" thermal="${3:-ok}"
  local deny="${HEATSINK_DENY_RATIO:-2.0}" thr="${HEATSINK_THROTTLE_RATIO:-0.9}"
  case "$load"  in ''|*[!0-9.]*) echo 0; return 0 ;; esac
  case "$cores" in ''|*[!0-9]*|0) echo 0; return 0 ;; esac
  local lvl
  lvl=$(awk -v l="$load" -v c="$cores" -v d="$deny" -v t="$thr" \
    'BEGIN { r = l / c; if (r >= d) print 2; else if (r >= t) print 1; else print 0 }')
  if [ "$thermal" = "pressure" ] && [ "$lvl" = "1" ]; then lvl=2; fi
  printf '%s\n' "$lvl"
}

# hs_target_workers CORES -> max(HEATSINK_MIN_WORKERS, cores/4)
hs_target_workers() {
  local cores="$1" min="${HEATSINK_MIN_WORKERS:-2}" n
  n=$(( cores / 4 ))
  [ "$n" -lt "$min" ] && n="$min"
  printf '%s\n' "$n"
}
