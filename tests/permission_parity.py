"""Compare synthetic reports with the original permission-report.py.

Run after a native release build:
  python3 tests/permission_parity.py --reference /path/to/permission-report.py
"""

import argparse
import difflib
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile


def write_jsonl(path, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(r) for r in records) + "\n")


def call(tool_id, command, outside=False):
    return {
        "type": "tool_use", "name": "Bash", "id": tool_id,
        "input": {"command": command, "dangerouslyDisableSandbox": outside},
    }


def result(tool_id, content):
    return {"type": "tool_result", "tool_use_id": tool_id, "content": content}


def session(*items):
    return {"type": "assistant", "message": {"content": list(items)}}


def fixtures(home):
    projects = home / ".claude/projects"
    events = home / ".local/state/claude/permission-events.jsonl"
    commands = [
        "git status", "cd /repo && env -u TOKEN A=1 git -C /repo --no-pager diff",
        "for x in a; do echo $(date); done", "while true; do break; done",
        "until false; do break; done", "echo `date` | cat", "echo $(date)",
        "x=1 npm run test", "echo ok || echo failed", "cd /repo; cargo test",
        "nix develop\nuv run check", "\u3000go\u3000test", "", "env -u",
        "bunx --yes formatter", "npx tool", "gh pr view", "git -C /repo",
        "echo '(for x)'", "true; \u3000for x in a", "X=1\x1cgit status",
        "(\u3000while true)", "echo x |\x1cA=1 echo y",
    ]
    reasons = [
        "Classifier unavailable: outage", "Auto mode could not evaluate safely",
        "Denied [external-repository]", "Denied [destructive] and [other]",
        "No rule []", "", None,
    ]
    rows = []
    rng = random.Random(42)
    for i in range(160):
        record = {
            "time": rng.choice([
                "2099-01-01T09:00:00+0900", "2099-01-01T00:00:00Z",
                "2098-12-31T19:00:00-05:00", "2099-1-1T0:0:0+000000.000001",
                "2000-01-01T00:00:00Z", "2099-02-30T00:00:00Z", "broken",
            ]),
            "event": rng.choice(["PermissionRequest", "PermissionDenied", "Other"]),
            "tool": "Bash", "command": rng.choice(commands),
            "cwd": rng.choice([str(home / "repo"), "/repo/other", "", None]),
            "session": rng.choice(["one", "two", "three", None]),
            "reason": rng.choice(reasons), "unsandboxed": i % 3 == 0,
        }
        if i % 11 == 0:
            record["tool"] = "Read"
        rows.append(record)
    for tool in [None, "Write", "Edit"]:
        rows.append({"time": "2099-01-01T00:00:00Z", "event": "PermissionRequest", "tool": tool})
    write_jsonl(events, rows)
    with events.open("ab") as stream:
        stream.write(b'broken JSON\n{"time":"2099-01-01T00:00:00Z","event":"PermissionRequest","tool":"Bash","command":"git sta\xfftus"}\r\n')
    output = (
        f"open {home}/repo/.git/config: Operation not permitted\n"
        f"'{home}/.cache/tool/a/b': Read-only file system\n"
        '"/tmp/cache/db/file": attempt to write a readonly database\n'
        "on /opt/cache/tool/a: Operation not permitted\n"
        "open /var/lib/db: Operation not permitted\n"
        "open /tmp/not-an-error: success\n"
        "deny network-outbound z.example:443\n"
        "deny network-outbound a.example\\suffix\n"
        "deny network-outbound z.example\x85suffix"
    )
    write_jsonl(projects / "first.jsonl", [
        session(call("shared", "cargo test"), result("shared", output)),
        session(call("rerun", "npm install", True), result("rerun", output)),
        session(call("no-error", "true"), result("no-error", "deny network-outbound network.example:80")),
        {"message": {"content": "conversation text is not evidence"}},
        session(result("unknown", output)),
        session(call("blocks", "git status"), result("blocks", [{"text": output}, 1, {"type": "image"}])),
    ])
    write_jsonl(projects / "nested/deep/.hidden/second.jsonl", [
        session(result("shared", output)),
        session(call("shared", "uv run test"), result("shared", output)),
        session(call("array", "go test"), result("array", [None, {"text": output}])),
    ])
    write_jsonl(projects / ".hidden.jsonl", [session(call("hidden", "git log", True))])
    write_jsonl(projects / "old.jsonl", [session(call("old", "excluded", True))])
    os.utime(projects / "old.jsonl", (946684800, 946684800))
    with (projects / "first.jsonl").open("ab") as stream:
        stream.write(b'not-json\n{"message":{"content":[{"type":"tool_use","name":"Bash","id":"bad-utf8","input":{"command":"npm ru\xffn test","dangerouslyDisableSandbox":true}}]}}\n')
    (projects / "directory-link").symlink_to(projects / "nested", target_is_directory=True)
    (projects / "file-link.jsonl").symlink_to(projects / ".hidden.jsonl")
    return projects, events


def compare(binary, reference, env, options, label):
    expected = subprocess.run([sys.executable, str(reference), *options], env=env, capture_output=True, check=True).stdout
    actual = subprocess.run([str(binary), "permissions", *options], env=env, capture_output=True, check=True).stdout
    if expected != actual:
        sys.stderr.writelines(difflib.unified_diff(
            expected.decode().splitlines(keepends=True), actual.decode().splitlines(keepends=True),
            fromfile=f"Python ({label})", tofile="MoonBit",
        ))
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--binary", type=Path, default=Path("_build/native/release/build/cmd/main/main.exe"))
    args = parser.parse_args()
    binary, reference = args.binary.resolve(), args.reference.resolve()
    with tempfile.TemporaryDirectory(prefix="permission-parity-") as directory:
        home = Path(directory)
        projects, events = fixtures(home)
        env = {**os.environ, "HOME": str(home)}
        for limit in [15, 1, 2, 0, -1, 100]:
            compare(binary, reference, env, ["--limit", str(limit)], f"limit {limit}")
        compare(binary, reference, env, ["--days", "-1", "--projects", str(projects), "--events", str(events)], "explicit paths and negative days")
        compare(binary, reference, env, ["--projects", str(home / "missing"), "--events", str(events)], "missing projects")
        compare(binary, reference, env, ["--projects", str(projects), "--events", str(home / "missing")], "missing events")
        compare(binary, reference, env, ["--projects", str(home / "missing"), "--events", str(home / "also-missing")], "no logs")
    print("10 permission parity scenarios passed")


if __name__ == "__main__":
    main()
