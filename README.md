# agents-retro

Find the instructions you keep repeating to your coding agents.

agents-retro reads your local Claude Code and Codex logs, keeps only the messages you typed, and counts them by the patterns you choose. A weekly look at those counts shows which requests, corrections, and nudges are worth turning into a hook, a setting, or a skill so you stop typing them.

## Install

Build from source with the [MoonBit](https://www.moonbitlang.com/) toolchain on macOS (Apple silicon) or Linux (x86_64).

```sh
git clone https://github.com/riii111/agents-retro
cd agents-retro
nix develop          # or install the moon toolchain yourself
moon build --target native --release
mkdir -p ~/.local/bin
install -m 755 _build/native/release/build/cmd/main/main.exe ~/.local/bin/agents-retro
```

If `agents-retro --help` is not found, add `~/.local/bin` to your `PATH`.

## Usage

```sh
agents-retro --days 7 --patterns patterns.json --out-dir ~/retro
```

The output prints how many messages each pattern matched and how that compares with the previous run in the same directory.

```text
Owner messages: 408 in 222 sessions (agent-to-agent messages excluded: 133)
  claude/main: 297
  codex/user: 74

Patterns (messages / sessions)  vs 2026-10-17
  Merge conflicts: 12 / 9  (was 18 / 13)
  Asking for shorter answers: 7 / 6  (was 5 / 4)
```

The output directory gets these files, named by date:

| File | Contents |
|---|---|
| `<date>-messages.tsv` | Every message you typed, one per line |
| `<date>-examples.tsv` | Up to three messages per pattern, each from a different session |
| `<date>-unmatched-<nn>.tsv` | Messages that match no pattern, 100 per file |
| `<date>-metrics.json` | Counts used for the next comparison |

Messages that agents sent to each other and text the apps inserted are left out.

## Patterns

The patterns file maps a category name to a regular expression. Start from [the example](skills/agents-retro/references/patterns.example.json) and add the phrases you notice yourself repeating.

```json
{
  "Merge conflicts": "[Cc]onflict",
  "Asking for shorter answers": "too long|shorter|more concise"
}
```

Use `[[:digit:]]`, `[[:space:]]`, and `[[:word:]]` instead of `\d`, `\s`, and `\w`, and write `-` inside brackets as `\-`.

## Let an agent run the retro

[skills/agents-retro](skills/agents-retro/SKILL.md) is a skill that runs agents-retro, reads the results, and writes a report with three to five concrete proposals. Copy it into your agent's skills directory, or point your own skill at it and add your project-specific steps.
