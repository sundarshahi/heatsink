#!/usr/bin/env bash
# Command classification + throttle rewrites.
# INVARIANT: a rewrite only ever REDUCES parallelism. Unsure -> warn (rc 1).

# Case-SENSITIVE + word-bounded on purpose: runners are lowercase, env vars
# are upper (VITEST_MAX_THREADS must never read as "vitest").
HS_HEAVY_RE='\b(rspec|parallel_rspec|parallel_tests?|vitest|jest|playwright|pytest|webpack|tsc|gradle|mvn|bazel)\b|\bturbo run\b|\b(next|nuxt|vite) build\b|\bnpm (run )?(test|build)\b|\b(yarn|pnpm|bun) (run )?(test|build)\b|\bcargo (test|build)\b|\bgo test\b|\bmake\b|\bcmake --build\b'

hs_is_heavy() {
  printf '%s' "$1" | grep -Eq "$HS_HEAVY_RE"
}

# hs_rewrite CMD N
#   rc 0 + stdout: rewritten command      (throttle)
#   rc 1, silent : heavy but no safe knob (warn)
#   rc 2, silent : already capped <= N    (allow unchanged)
# shellcheck disable=SC2221,SC2222
hs_rewrite() {
  local cmd="$1" n="$2" cur
  case "$cmd" in
    *parallel_rspec*|*parallel_test*|*rspec*)
      cur=$(printf '%s' "$cmd" | sed -n 's/.*PARALLEL_TEST_PROCESSORS=\([0-9][0-9]*\).*/\1/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "${cmd/PARALLEL_TEST_PROCESSORS=$cur/PARALLEL_TEST_PROCESSORS=$n}"
      else
        printf 'PARALLEL_TEST_PROCESSORS=%s %s\n' "$n" "$cmd"
      fi
      return 0 ;;

    *vitest*|*jest*)
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*--maxWorkers[= ]([0-9]+).*/\1/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/--maxWorkers[= ]$cur/--maxWorkers=$n/"
      else
        printf '%s --maxWorkers=%s\n' "$cmd" "$n"
      fi
      return 0 ;;

    *playwright*)
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*--workers[= ]([0-9]+).*/\1/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/--workers[= ]$cur/--workers=$n/"
      else
        printf '%s --workers=%s\n' "$cmd" "$n"
      fi
      return 0 ;;

    *pytest*)
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*(-n|--numprocesses)[= ]([0-9]+).*/\2/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/(-n|--numprocesses)[= ]$cur/\1 $n/"
        return 0
      fi
      return 1 ;;  # xdist may not be installed; adding -n could break the run

    *"cargo test"*)
      if printf '%s' "$cmd" | grep -q -- '--test-threads'; then
        cur=$(printf '%s' "$cmd" | sed -n -E 's/.*--test-threads[= ]([0-9]+).*/\1/p')
        [ -n "$cur" ] || return 1
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/--test-threads[= ]$cur/--test-threads=$n/"
      else
        printf '%s -- --test-threads=%s\n' "$cmd" "$n"
      fi
      return 0 ;;

    *"cargo build"*)
      # A forwarded -j/--jobs flag wins over CARGO_BUILD_JOBS env, so check first.
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*(-j|--jobs)[= ]?([0-9]+).*/\2/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/(-j|--jobs)[= ]?$cur/\1 $n/"
        return 0
      fi
      if printf '%s' "$cmd" | grep -q 'CARGO_BUILD_JOBS='; then
        cur=$(printf '%s' "$cmd" | sed -n 's/.*CARGO_BUILD_JOBS=\([0-9][0-9]*\).*/\1/p')
        [ -n "$cur" ] && [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "${cmd/CARGO_BUILD_JOBS=$cur/CARGO_BUILD_JOBS=$n}"
      else
        printf 'CARGO_BUILD_JOBS=%s %s\n' "$n" "$cmd"
      fi
      return 0 ;;

    *"go test"*)
      # -p accepts space, =, or no separator: -p 16 / -p=16 / -p16
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*-p[= ]?([0-9]+).*/\1/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/-p[= ]?$cur/-p $n/"
      else
        printf '%s -p %s\n' "$cmd" "$n"
      fi
      return 0 ;;

    *make*)
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*-j *([0-9]+).*/\1/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf '%s\n' "$cmd" | sed -E "s/-j *$cur/-j $n/"
        return 0
      fi
      return 1 ;;  # bare make is serial — NEVER add -j

    *"npm test"*|*"npm run test"*|*"npm build"*|*"npm run build"*|*"yarn test"*| \
    *"yarn build"*|*"yarn run test"*|*"yarn run build"*|*"pnpm test"*|*"pnpm build"*| \
    *"pnpm run "*|*"bun test"*|*"bun build"*|*"bun run "*|*"turbo run"*)
      # A forwarded --maxWorkers/--workers flag wins over the env var, so
      # check for one first: rc 0 must mean parallelism actually drops.
      cur=$(printf '%s' "$cmd" | sed -n -E 's/.*--(maxWorkers|workers)[= ]([0-9]+).*/\2/p')
      if [ -n "$cur" ]; then
        [ "$cur" -le "$n" ] && return 2
        printf 'VITEST_MAX_THREADS=%s %s\n' "$n" "$cmd" | sed -E "s/--(maxWorkers|workers)[= ]$cur/--\1=$n/"
      else
        printf 'VITEST_MAX_THREADS=%s %s\n' "$n" "$cmd"
      fi
      return 0 ;;

    *) return 1 ;;  # heavy but unknown shape -> warn, never mangle
  esac
}
