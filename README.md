# agents-retro

Find repeated instructions and permission interruptions worth turning into hooks, settings, or skills.

agents-retro reads local Claude Code and Codex logs to show what keeps interrupting your work. It counts the messages you typed and Claude Code permission or sandbox problems.

## Install

Download the binary from the [latest release](https://github.com/riii111/agents-retro/releases/latest). It supports macOS (Apple silicon) and Linux (x86_64):

```sh
target=darwin-arm64   # or linux-x86_64
curl -fsSL "https://github.com/riii111/agents-retro/releases/latest/download/agents-retro-$target.tar.gz" | tar -xz
mkdir -p ~/.local/bin
install -m 755 agents-retro ~/.local/bin/agents-retro
```

Add `~/.local/bin` to your `PATH` if needed.

## Repeated instructions

Create `patterns.json` from [the example](skills/agents-retro/references/patterns.example.json), then run:

```sh
agents-retro messages --days 7 --patterns patterns.json --out-dir ~/retro
```

Each pattern maps a category to a regular expression. Use `[[:digit:]]`, `[[:space:]]`, and `[[:word:]]` instead of `\d`, `\s`, and `\w`, and write `-` inside brackets as `\-`.

The report counts matching messages and sessions and compares them with the previous run. Dated messages, examples, unmatched messages, and metrics are saved in the output directory. Agent-to-agent messages and app-inserted text, including expanded skill bodies, are excluded.

Two options add detail:

- `--by-week` shows the period and the counts per app and per week. Weeks are UTC and start on Monday.
- `--candidates candidates.json` counts trial patterns, in the same format as `patterns.json`, apart from the real ones.

With either option, the comparison with the previous run is shown only when that run covered the same number of days.

## Permission interruptions

```sh
agents-retro permissions --days 7 --limit 15
```

See recurring Claude Code permission prompts, auto mode denials, and sandbox failures by command, path, or host. Prompts and denials require [permission event recording](skills/permission-analyze/references/recording.md); sandbox failures use existing session logs. Codex approval events are outside its scope.

## Detailed breakdowns

These commands print JSON, mainly for agents that back up improvement proposals. Each takes `--days` and `--limit`, like `permissions`.

```sh
agents-retro tokens --days 7 --limit 15
```

| Command | What it counts |
| --- | --- |
| `tokens` | Token use by project, session, and preceding tool call, plus the largest tool results, whose `chars` counts UTF-16 code units |
| `hooks` | Operations blocked by hooks, by message, tool, and command |
| `skills` | Skill and subagent calls, plus installed skills never used |
| `interrupts` | Your interruptions and rejected tool calls, by project and session |
| `tools` | Failed tool calls by tool and command, including repeated failures |

Subagent logs are included. `tokens` and `skills` also read Codex logs; the others read Claude Code logs only.

## Agent skills

Copy either skill directory into your agent's skills directory, or reference it from your own skill:

- [agents-retro](skills/agents-retro/SKILL.md): review repeated instructions and propose ways to stop repeating them.
- [permission-analyze](skills/permission-analyze/SKILL.md): interpret permission reports and propose settings improvements.
