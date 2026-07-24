# heatsink — Your AI coding agent doesn't know your laptop is on fire.

## The war story

My MacBook is a 10-core machine. One afternoon it sat at a load average of
**99**. Not 9.9 — 99. Ten cores, ninety-nine runnable processes queued up
behind them.

The cause: ten orphaned `yes` processes, each pinned to a core, each burning
CPU for nothing, for **24 hours straight**. Somewhere along the way an agent
had spun up a background loop, the parent that was supposed to manage it
died or moved on, and the children just kept running — orphaned, invisible,
permanent. On top of that pile, a parallel vitest suite (also agent-spawned)
tried to fan out across every core it could find.

The agent doing all this had no idea any of it was happening. It saw a shell,
it ran a command, the command returned (eventually), it moved to the next
task. It had no concept of "the machine is on fire" — no load signal, no
thermal signal, no notion that the last five commands it ran are still
running. It just kept scheduling more parallel work onto a machine that
had none left to give.

heatsink exists so that never has to happen silently again.

## What it does

heatsink sits between an AI coding agent and your shell. Before a command
runs, it checks load and thermal state and does one of four things:

- **ok** — nothing unusual, run as-is.
- **warn** — near saturation, command runs but the agent is told to hold off
  on stacking more parallel work.
- **throttle** — command matches a known heavy build/test runner and has a
  parallelism knob heatsink can safely lower; the rewritten command runs
  instead.
- **deny** — already oversubscribed (or the OS is thermally throttling);
  the command doesn't run at all.

**The one invariant that matters: a rewrite only ever *reduces* parallelism.**
heatsink never raises a worker count, never adds `-j` to a bare `make`, and
never guesses at a knob it isn't sure about — when it can't rewrite safely,
it warns instead of mangling your command.

### Auto-throttle table

| Command | How it's detected | Rewrite behavior |
|---|---|---|
| `rspec`, `parallel_rspec`, `parallel_test(s)` | `PARALLEL_TEST_PROCESSORS=N` env var | Lowers an existing value, or prepends the env var if absent |
| `vitest`, `jest` | `--maxWorkers[= ]N` | Lowers an existing value, or appends `--maxWorkers=N` if absent |
| `playwright` | `--workers[= ]N` | Lowers an existing value, or appends `--workers=N` if absent |
| `pytest` | `-n`/`--numprocesses N` | Lowers an existing value; if pytest-xdist isn't already in use, **warns instead of adding `-n`** — forcing it on could break a suite that never installed xdist |
| `cargo test` | `--test-threads[= ]N` | Lowers an existing value, or appends `-- --test-threads=N` if absent |
| `cargo build` | `CARGO_BUILD_JOBS=N` env var | Lowers an existing value, or prepends the env var if absent |
| `go test` | `-p`, `-p=`, or `-pN` (all three forms) | Lowers an existing value, or appends `-p N` if absent |
| `make` | `-j N` | Lowers an existing value; **bare `make` (no `-j`) is left alone** — make defaults to serial, and heatsink never adds parallelism, only removes it |
| `npm`/`yarn`/`pnpm`/`bun` `test`/`build`, `turbo run` | a forwarded `--maxWorkers`/`--workers` flag | A forwarded flag is honored and lowered (it wins over env vars); otherwise heatsink prepends `VITEST_MAX_THREADS=N` |
| `webpack`, `tsc`, `gradle`, `mvn`, `bazel`, `cmake --build` | — | Flagged as heavy but has no known safe knob — always **warn**, never rewritten |

### `doctor` — why is my machine hot?

```
$ heatsink doctor
heatsink doctor

  load:    99 on 10 cores (9.9x)  thermal: ok

  top burners:
    99001   99.0%  99:00:00     yes
    85      99.0%  99:00:00     lowpid_burner
    91002   95.0%  05:12        ruby young_script.rb
    91001   95.0%  02:11:09     ruby stuck_script.rb
    62652   67.2%  03:04        node /repo/node_modules/.bin/vitest
    74586   41.2%  24:01:11     yes

  orphaned burners (parent gone, still spinning):
    pid 74586   41.2%  up 24:01:11     yes
    pid 74587   40.6%  up 24:01:11     yes
    pid 91001   95.0%  up 02:11:09     ruby stuck_script.rb

  verdict: orphaned processes are burning CPU for nothing.
           reap them:  heatsink reap        (report)
                       heatsink reap --kill (terminate)
```

`doctor` shows your load-to-core ratio, the top CPU consumers on the box, and
separately calls out **orphans**: processes whose parent process is gone but
that are still spinning (the reap-safe signal — a process that's still
attached to a live parent is never a reap candidate).

### `reap` — clean up the orphans

```bash
heatsink reap          # report-only: lists orphaned burners, kills nothing
heatsink reap --kill   # SIGTERM, wait, SIGKILL any survivors
```

`reap` defaults to report-only on purpose — a guard that can autonomously
kill your processes is a guard nobody will trust. You always have to ask for
`--kill` explicitly.

## Install

**Claude Code (plugin):**

```
/plugin marketplace add sundarshahi/heatsink
/plugin install heatsink@heatsink
```

The plugin wires itself into Claude Code's `PreToolUse` hook automatically —
no further setup.

**CLI (any agent, any shell):**

```bash
git clone https://github.com/sundarshahi/heatsink
cd heatsink
make install   # installs to ~/.local/bin
```

## Adapter status

| Adapter | Status |
|---|---|
| `claude-code` | tested |
| `cursor` | untested in the wild |
| `codex` | experimental |
| generic `wrap` | tested |

`cursor` is built against Cursor's documented `beforeShellExecution` hooks
contract but isn't exercised in CI against a real Cursor install. `codex`
speaks a minimal stdin/stdout contract since Codex's own hook surface isn't
stable yet. If either misbehaves against a real harness, please open an
issue with the raw hook input/output — that's exactly the feedback needed to
move them out of "untested."

The generic `wrap` command works with anything that can shell out — CI jobs,
Makefiles, pre-commit hooks, or an agent with no native hook surface at all:

```bash
heatsink wrap -- bundle exec rspec spec/
```

## Tuning

heatsink's thresholds are load-ratio-based (load average ÷ core count), and
every one of them is an environment variable:

| Variable | Default | Meaning |
|---|---|---|
| `HEATSINK_DENY_RATIO` | `2.0` | load/cores at or above this → **deny** (oversubscribed) |
| `HEATSINK_THROTTLE_RATIO` | `0.9` | load/cores at or above this → **throttle/warn** zone |
| `HEATSINK_MIN_WORKERS` | `2` | floor on the worker count heatsink will rewrite down to (target is `max(MIN_WORKERS, cores/4)`) |

## Why no temperature on macOS

macOS exposes no root-free CPU thermometer. The only interface that reports
actual junction temperature, `powermetrics`, requires `sudo` — and a guard
that has to ask for `sudo` to make a safety decision is a guard that will get
disabled the first time it's inconvenient. heatsink never asks for elevated
privileges.

Instead, on macOS heatsink governs **load** — the thing that's actually
causing the problem — and reads the OS's own throttle signal when it
surfaces one (`pmset -g therm`, checking `CPU_Speed_Limit`). If macOS itself
is throttling the CPU, heatsink treats that as thermal pressure and
escalates the throttle-zone verdict straight to deny.

On Linux, no such workaround is needed: `/sys/class/thermal/thermal_zone*/temp`
is readable without elevated privileges, so heatsink reads real per-zone
temperatures directly and treats 85°C or above as thermal pressure.

## Known limitation

heatsink classifies and rewrites a command as a single unit. For a compound
command (`cmd1 && cmd2`), only the **first pattern that matches** in
heatsink's classifier gets rewritten — the rest of the chain runs verbatim,
untouched, whether or not it's also heavy. If you're chaining multiple heavy
commands together, either wrap them separately or expect only one leg of the
chain to be throttled.

## Fail-open guarantee

Every layer of heatsink is designed to fail open. If `jq` isn't installed, if
stdin isn't valid JSON, if a signal read fails, if anything at all goes
wrong — heatsink gets out of the way and your command runs exactly as you
typed it. A guard that can break your workflow by breaking itself is worse
than no guard at all.

## License

MIT — see [LICENSE](LICENSE).
