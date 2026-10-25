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

## Permission analysis

Find recurring Claude Code permission prompts, auto mode denials, and Bash sandbox failures:

```sh
agents-retro permissions --days 7 --limit 15
```

Session logs default to `~/.claude/projects`; permission events default to `~/.local/state/claude/permission-events.jsonl` and require a `log-permission-event` hook. Override them with `--projects <directory>` and `--events <file>`. The report prints counts by command, denial cause, working directory, blocked path, and host. It includes session counts for permission commands and does not quote conversation text or tool output. Codex approval events are outside its scope.

[skills/permission-analyze](skills/permission-analyze/SKILL.md) guides an agent through interpreting the report and proposing settings improvements.

### Record permission events

Save the [reference recording hook](https://github.com/riii111/dotfiles/blob/a7676980f60f2cf1ae3f1243714b80e2159a6ac6/dot_claude/hooks/executable_log-permission-event.py) as `~/.claude/hooks/log-permission-event.py`. It requires Python 3, reads Claude Code's hook input from standard input, and appends records to `~/.local/state/claude/permission-events.jsonl` without returning a permission decision. The hook is maintained separately from agents-retro.

Merge these entries into `hooks` in `~/.claude/settings.json`, following [Claude Code's hook configuration](https://code.claude.com/docs/en/hooks#configuration):

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          { "type": "command", "command": "python3 \"$HOME/.claude/hooks/log-permission-event.py\"" }
        ]
      }
    ],
    "PermissionDenied": [
      {
        "hooks": [
          { "type": "command", "command": "python3 \"$HOME/.claude/hooks/log-permission-event.py\"" }
        ]
      }
    ]
  }
}
```

`PermissionRequest` records permission prompts; `PermissionDenied` records auto mode denials. Each record is one JSON object terminated by LF. The hook maps `hook_event_name`, `session_id`, `permission_mode`, and `tool_name` to `event`, `session`, `mode`, and `tool`, and copies `cwd`. It adds local `time` in the fixed format `YYYY-MM-DDTHH:MM:SS+HHMM` or `-HHMM`. Bash records include `command` and Boolean `unsandboxed`; denials can include `reason`.

```jsonl
{"time":"2026-10-25T09:00:00+0900","event":"PermissionRequest","session":"s1","cwd":"/repo","mode":"auto","tool":"Bash","command":"git status","unsandboxed":false}
{"time":"2026-10-25T09:01:00+0900","event":"PermissionDenied","session":"s1","cwd":"/repo","mode":"auto","tool":"Bash","command":"git push","unsandboxed":false,"reason":"[External Repository]"}
```

The reference hook limits commands to 500 characters and reasons to 300, and creates the event file with mode `0600`. Use `--events <file>` when another recorder writes the same format elsewhere.

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
