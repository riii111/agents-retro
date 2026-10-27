# agents-retro

Find repeated instructions and permission interruptions worth turning into hooks, settings, or skills.

agents-retro reads local Claude Code and Codex logs to show what keeps interrupting your work. It counts the messages you typed and Claude Code permission or sandbox problems.

## Install

Build from source with [MoonBit](https://www.moonbitlang.com/) on macOS (Apple silicon) or Linux (x86_64):

```sh
git clone https://github.com/riii111/agents-retro
cd agents-retro
nix develop          # or install the moon toolchain yourself
moon build --target native --release
mkdir -p ~/.local/bin
install -m 755 _build/native/release/build/cmd/main/main.exe ~/.local/bin/agents-retro
```

Add `~/.local/bin` to your `PATH` if needed.

## Repeated instructions

Create `patterns.json` from [the example](skills/agents-retro/references/patterns.example.json), then run:

```sh
agents-retro messages --days 7 --patterns patterns.json --out-dir ~/retro
```

Each pattern maps a category to a regular expression. Use `[[:digit:]]`, `[[:space:]]`, and `[[:word:]]` instead of `\d`, `\s`, and `\w`, and write `-` inside brackets as `\-`.

The report counts matching messages and sessions and compares them with the previous run. Dated messages, examples, unmatched messages, and metrics are saved in the output directory. Agent-to-agent messages and app-inserted text are excluded.

## Permission interruptions

```sh
agents-retro permissions --days 7 --limit 15
```

See recurring Claude Code permission prompts, auto mode denials, and sandbox failures by command, path, or host. Prompts and denials require [permission event recording](skills/permission-analyze/references/recording.md); sandbox failures use existing session logs. Codex approval events are outside its scope.

## Token usage

```sh
agents-retro tokens --days 7 --limit 15
```

Prints JSON showing which projects, sessions, and preceding tool calls used the most tokens, and which tool results were largest. It covers Claude Code and Codex, including subagent logs, and reports the cache read ratio for each session.

## Agent skills

Copy either skill directory into your agent's skills directory, or reference it from your own skill:

- [agents-retro](skills/agents-retro/SKILL.md): review repeated instructions and propose ways to stop repeating them.
- [permission-analyze](skills/permission-analyze/SKILL.md): interpret permission reports and propose settings improvements.
