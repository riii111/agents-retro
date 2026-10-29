///|
let test_now_ms : Int64 = 1_793_143_854_000L

///|
async test "interrupts reads Claude Code logs including subagent files" {
  let dir = @fs.tmpdir(prefix="interrupts-report")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  @fs.mkdir("\{projects}/p/s1/subagents", recursive=true)
  @fs.write_file(
    "\{projects}/p/s1.jsonl",
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u1","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
    ),
  )
  @fs.write_file(
    "\{projects}/p/s1/subagents/agent-a.jsonl",
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u2","sessionId":"s1","cwd":"/w","isSidechain":true,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}
    ),
  )
  let matches = command(dir).parse(argv=["--projects", projects])

  let output = report(matches, test_now_ms)

  assert_true(output.contains("\"records\":2"))
  assert_true(
    output.contains(
      "\"total\":{\"interrupts\":1,\"tool_use_interrupts\":1,\"rejections\":0,\"total\":2,\"sidechain_total\":1}",
    ),
  )
}

///|
async test "interrupts rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="interrupts-options")
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
