# heatsink — generic wrapper

Works with any harness, script, Makefile, CI job, or pre-commit hook:

```bash
heatsink wrap -- bundle exec rspec spec/
```

- ok/warn → runs your command (warn prints a note to stderr)
- throttle → runs the reduced-worker rewrite and prints what changed
- deny → exits 75 (EX_TEMPFAIL) without running

Make example:

```make
test:
	heatsink wrap -- npx vitest run
```
