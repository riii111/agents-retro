# CLI wiring

The executable built from `cmd/main` is `main.exe`.

## Version

```mooncram
$ main.exe --version
0.1.0
```

## Arguments reach the report

`--projects`, `--days` and `--limit` select the logs and shape the JSON on standard output.
The fixture has no timestamps, so a copy gets the current UTC time on every record and a current file modification time.

```mooncram
$ mkdir projects && sed "s/^{/{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",/" "$TESTDIR/fixtures/cli/projects/demo/s1.jsonl" > projects/s1.jsonl
```

```mooncram
$ main.exe tools --projects projects --days 3 --limit 5
{"days":3,"records":1,"total":{"failures":1,"repeats":0,"sidechain_failures":0,"sessions":1},"tools":[{"tool":"Bash","command":"cargo test","failures":1,"repeats":0,"sidechain_failures":0,"sessions":1}]}
```

## Unknown subcommand

Nothing is written to standard output and the exit code is 1.

```mooncram
$ main.exe bogus 2>/dev/null
[1]
```

## Invalid option value

```mooncram
$ main.exe tools --days abc 2>/dev/null
[1]
```
