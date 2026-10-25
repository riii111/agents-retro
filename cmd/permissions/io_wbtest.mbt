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
  @fs.symlink(target="\{dir}/missing.jsonl", "\{dir}/dangling.jsonl")
  let found = records(dir, 0L)
  found.sort_by((a, b) => a.lexical_compare(b))
  assert_eq(found, [
    "\{dir}/.hidden/deep/session.jsonl",
    "\{dir}/alias.jsonl",
    "\{dir}/archive.jsonl/session.jsonl",
    "\{dir}/root.jsonl",
  ])
  let options = command(dir).parse(argv=[
    "--projects",
    dir,
    "--events",
    "\{dir}/missing",
  ])
  let output = report(options, dir, 7L * 86_400_000L)
  assert_true(output.contains("4 session records"))
  assert_true(output.contains("    1  uv run\n"))
  assert_eq(records(dir, 253402300799000L), [])
  assert_eq(records("\{dir}/missing", 0L), [])
}

///|
async test "permissions rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="permission-options")
  defer @fs.rmdir(dir, recursive=true)
  let paths = ["--projects", "\{dir}/missing", "--events", "\{dir}/missing"]
  for
    args in [["--days", "-1"], ["--limit", "-1"], ["--days=-1"], ["--limit=-1"]] {
    let options = command(dir).parse(argv=paths + args)
    let error = try {
      ignore(report(options, dir, 0L))
      ""
    } catch {
      err => err.to_string()
    }
    assert_true(error.contains("must be non-negative"))
  }
  for args in [[], ["--days", "0", "--limit", "0"], ["--days=0", "--limit=0"]] {
    let options = command(dir).parse(argv=paths + args)
    let output = report(options, dir, 0L)
    assert_true(output.contains("0 session records"))
    assert_true(output.has_suffix("## Hosts the sandbox refused\n(none)\n\n"))
  }
}

///|
async test "permission report keeps tool records and Unicode events with permission filtering" {
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
  let matches = command("/home/me").parse(argv=[
    "--projects", projects, "--events", events,
  ])
  let output = report(matches, "/home/me", 7L * 86_400_000L)
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
