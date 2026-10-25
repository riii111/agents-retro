///|
test "permissions options do not require message report arguments" {
  let matches = app_command("/home/me").parse(argv=["permissions"])
  guard matches.subcommand is Some(("permissions", permissions)) else {
    fail("missing permissions subcommand")
  }
  assert_eq(permissions.values["days"], ["7"])
  assert_eq(permissions.values["limit"], ["15"])
  assert_eq(permissions.values["projects"], ["/home/me/.claude/projects"])
  assert_eq(permissions.values["events"], [
    "/home/me/.local/state/claude/permission-events.jsonl",
  ])
  let messages = app_command("/home/me").parse(argv=[
    "--days", "3", "--patterns", "patterns.json", "--out-dir", "out",
  ])
  assert_eq(message_paths(messages), ("patterns.json", "out"))
  assert_eq(messages.values["days"], ["3"])
  for args in [[], ["--patterns", "patterns.json"], ["--out-dir", "out"]] {
    let rejected = try {
      ignore(message_paths(app_command("/home/me").parse(argv=args)))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
async test "chunked JSONL reader preserves long Unicode records and the final line" {
  let dir = @fs.tmpdir(prefix="permission-jsonl")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/session.jsonl"
  let long = "x".repeat((1 << 20) - 2) + "\u{2028}tail"
  @fs.write_file(path, "\{long}\n\nlast")
  let lines = []
  each_line(path, line => lines.push(@utf8.decode_lossy(line)))
  assert_eq(lines, [long, "", "last"])
}

///|
async test "permission traversal reads hidden descendants without following directory symlinks" {
  let dir = @fs.tmpdir(prefix="permission-projects")
  defer @fs.rmdir(dir, recursive=true)
  @fs.mkdir("\{dir}/.hidden/deep", recursive=true)
  @fs.write_file("\{dir}/.hidden/deep/session.jsonl", "{}")
  @fs.write_file("\{dir}/root.jsonl", "{}")
  @fs.mkdir("\{dir}/archive.jsonl")
  @fs.write_file(
    "\{dir}/archive.jsonl/session.jsonl",
    (
      #|{"message":{"content":[{"type":"tool_use","id":"one","name":"Bash","input":{"command":"uv run test","dangerouslyDisableSandbox":true}}]}}
    ),
  )
  @fs.symlink(target="\{dir}/.hidden", "\{dir}/link")
  @fs.symlink(target="\{dir}/.hidden/deep/session.jsonl", "\{dir}/alias.jsonl")
  let records = permission_records(dir, 0L)
  records.sort_by((a, b) => a.lexical_compare(b))
  assert_eq(records, [
    "\{dir}/.hidden/deep/session.jsonl",
    "\{dir}/alias.jsonl",
    "\{dir}/archive.jsonl/session.jsonl",
    "\{dir}/root.jsonl",
  ])
  let options = permission_command(dir).parse(argv=[
    "--projects",
    dir,
    "--events",
    "\{dir}/missing",
  ])
  let output = permission_report(options, dir, 7L * 86_400_000L)
  assert_true(output.contains("4 session records"))
  assert_true(output.contains("    1  uv run\n"))
  assert_eq(permission_records(dir, 253402300799000L), [])
  assert_eq(permission_records("\{dir}/missing", 0L), [])
}

///|
async test "permissions rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="permission-options")
  defer @fs.rmdir(dir, recursive=true)
  let paths = ["--projects", "\{dir}/missing", "--events", "\{dir}/missing"]
  for
    args in [["--days", "-1"], ["--limit", "-1"], ["--days=-1"], ["--limit=-1"]] {
    let options = permission_command(dir).parse(argv=paths + args)
    let error = try {
      ignore(permission_report(options, dir, 0L))
      ""
    } catch {
      err => err.to_string()
    }
    assert_true(error.contains("must be non-negative"))
  }
  for args in [[], ["--days", "0", "--limit", "0"], ["--days=0", "--limit=0"]] {
    let options = permission_command(dir).parse(argv=paths + args)
    let output = permission_report(options, dir, 0L)
    assert_true(output.contains("0 session records"))
    assert_true(output.has_suffix("## Hosts the sandbox refused\n(none)\n\n"))
  }
}

///|
async test "permission report streams tool records and raw Unicode events without message filtering" {
  let dir = @fs.tmpdir(prefix="permission-report")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  let events = "\{dir}/events.jsonl"
  @fs.mkdir(projects)
  @fs.write_file(
    "\{projects}/session.jsonl",
    "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"one\",\"name\":\"Bash\",\"input\":{\"command\":\"git\u{2028}status\"}}]}}\n{\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"one\",\"content\":\"open /home/me/repo/.git/config: Operation not permitted\"}]}}",
  )
  @fs.write_file(
    events, "{\"time\":\"1970-01-01T00:00:00+0000\",\"event\":\"PermissionRequest\",\"tool\":\"Bash\",\"command\":\"git\u{2028}status\",\"cwd\":\"/home/meow/x\"}\nnot json\n{\"time\":\"1969-12-31T23:59:59+0000\",\"event\":\"PermissionRequest\",\"tool\":\"Bash\",\"command\":\"excluded\"}",
  )
  let matches = app_command("/home/me").parse(argv=[
    "permissions", "--projects", projects, "--events", events,
  ])
  guard matches.subcommand is Some((_, permissions)) else {
    fail("missing subcommand")
  }
  let output = permission_report(permissions, "/home/me", 7L * 86_400_000L)
  assert_true(output.contains("1 session records"))
  assert_true(output.contains("    1  git status  (1 sessions)"))
  assert_true(output.contains("    1  /home/meow/x\n"))
  assert_true(
    output.contains(
      "## Sandboxed commands that failed to write\n    1  git status\n",
    ),
  )
  assert_true(output.contains("    1  ~/repo/.git\n"))
  assert_false(output.contains("excluded"))
}
