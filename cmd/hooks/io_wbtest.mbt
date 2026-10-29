///|
let test_now_ms : Int64 = 1_793_143_854_000L

///|
async test "hooks reads Claude Code logs including subagent files" {
  let dir = @fs.tmpdir(prefix="hooks-report")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  @fs.mkdir("\{projects}/p/s1/subagents", recursive=true)
  @fs.write_file(
    "\{projects}/p/s1.jsonl",
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","isSidechain":false,"message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cat a"}}]}}
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","isSidechain":false,"message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"PreToolUse:Bash hook error: Use bat instead of cat!"}]}}
    ),
  )
  @fs.write_file(
    "\{projects}/p/s1/subagents/agent-a.jsonl",
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","isSidechain":true,"message":{"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"cat b"}}]}}
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","isSidechain":true,"message":{"content":[{"type":"tool_result","tool_use_id":"t2","is_error":true,"content":"PreToolUse:Bash hook error: Use bat instead of cat!"}]}}
    ),
  )
  let matches = command(dir).parse(argv=["--projects", projects])

  let output = report(matches, test_now_ms)

  assert_true(output.contains("\"records\":2"))
  assert_true(
    output.contains(
      "\"total\":{\"blocks\":2,\"sessions\":1,\"sidechain_blocks\":1}",
    ),
  )
  assert_true(output.contains("\"command\":\"cat\",\"blocks\":2"))
}

///|
async test "hooks rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="hooks-options")
  defer @fs.rmdir(dir, recursive=true)
  let paths = ["--projects", "\{dir}/missing"]

  for
    args in [["--days", "-1"], ["--limit", "-1"], ["--days=-1"], ["--limit=-1"]] {
    let options = command(dir).parse(argv=paths + args)

    let error = try {
      ignore(report(options, 0L))
      ""
    } catch {
      err => err.to_string()
    }

    assert_true(error.contains("must be non-negative"))
  }

  for args in [["--days", "0", "--limit", "0"], ["--days=0", "--limit=0"]] {
    let options = command(dir).parse(argv=paths + args)

    ignore(report(options, 0L))
  }
}
