# Record permission events

Permission prompts and auto mode denials need a recording hook. Sandbox failures use the existing session logs in `~/.claude/projects`. Use `--projects <directory>` and `--events <file>` to read other locations.

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

