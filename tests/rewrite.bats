#!/usr/bin/env bats
load helpers

setup() { . "$HS_REPO/lib/rewrite.sh"; }

# --- classification ---
@test "heavy: real runners match" {
  for c in "bundle exec rspec spec/" "npx vitest run" "npm run build" "npm test" \
           "pytest -n 8" "go test ./..." "cargo test" "make -j8" "npx tsc --noEmit" \
           "yarn build" "npx playwright test" "npx jest"; do
    hs_is_heavy "$c" || { echo "should be heavy: $c"; return 1; }
  done
}

@test "not heavy: false-positive regressions" {
  for c in "jq -c .env.VITEST_MAX_THREADS settings.json" \
           "echo PARALLEL_TEST_PROCESSORS=4" "git status" "ls Makefile" \
           "cat jester.txt" "grep vitesty file"; do
    ! hs_is_heavy "$c" || { echo "should NOT be heavy: $c"; return 1; }
  done
}

# --- rewrites (rc 0 + output) ---
@test "rspec gets PARALLEL_TEST_PROCESSORS prefix" {
  run hs_rewrite "bundle exec rspec spec/" 2
  [ "$status" -eq 0 ]
  [ "$output" = "PARALLEL_TEST_PROCESSORS=2 bundle exec rspec spec/" ]
}

@test "existing PARALLEL_TEST_PROCESSORS is lowered, not doubled" {
  run hs_rewrite "PARALLEL_TEST_PROCESSORS=8 bundle exec parallel_rspec spec/" 2
  [ "$status" -eq 0 ]
  [ "$output" = "PARALLEL_TEST_PROCESSORS=2 bundle exec parallel_rspec spec/" ]
}

@test "vitest gets --maxWorkers appended" {
  run hs_rewrite "npx vitest run" 2
  [ "$status" -eq 0 ]
  [ "$output" = "npx vitest run --maxWorkers=2" ]
}

@test "existing higher --maxWorkers is lowered" {
  run hs_rewrite "npx jest --maxWorkers=8" 2
  [ "$status" -eq 0 ]
  [ "$output" = "npx jest --maxWorkers=2" ]
}

@test "playwright gets --workers appended" {
  run hs_rewrite "npx playwright test" 2
  [ "$status" -eq 0 ]
  [ "$output" = "npx playwright test --workers=2" ]
}

@test "go test gets -p appended" {
  run hs_rewrite "go test ./..." 2
  [ "$status" -eq 0 ]
  [ "$output" = "go test ./... -p 2" ]
}

@test "cargo test gets --test-threads" {
  run hs_rewrite "cargo test" 2
  [ "$status" -eq 0 ]
  [ "$output" = "cargo test -- --test-threads=2" ]
}

@test "cargo build gets CARGO_BUILD_JOBS prefix" {
  run hs_rewrite "cargo build --release" 2
  [ "$status" -eq 0 ]
  [ "$output" = "CARGO_BUILD_JOBS=2 cargo build --release" ]
}

@test "make -j8 is lowered to -j 2" {
  run hs_rewrite "make -j8 all" 2
  [ "$status" -eq 0 ]
  [ "$output" = "make -j 2 all" ]
}

@test "npm test gets VITEST_MAX_THREADS prefix" {
  run hs_rewrite "npm test" 2
  [ "$status" -eq 0 ]
  [ "$output" = "VITEST_MAX_THREADS=2 npm test" ]
}

# --- allow unchanged (rc 2) ---
@test "already at/below target passes through" {
  run hs_rewrite "npx vitest run --maxWorkers=2" 2
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  run hs_rewrite "make -j2" 4
  [ "$status" -eq 2 ]
}

# --- no safe knob (rc 1) ---
@test "bare make never gains -j" {
  run hs_rewrite "make all" 2
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "pytest without xdist flag warns instead of rewriting" {
  run hs_rewrite "pytest tests/" 2
  [ "$status" -eq 1 ]
}

@test "pytest with higher -n is lowered" {
  run hs_rewrite "pytest -n 8 tests/" 2
  [ "$status" -eq 0 ]
  [ "$output" = "pytest -n 2 tests/" ]
}

@test "tsc has no knob -> warn" {
  run hs_rewrite "npx tsc --noEmit" 2
  [ "$status" -eq 1 ]
}
