///|
async test "tokens reads Claude Code and Codex logs including subagent files" {
  let dir = @fs.tmpdir(prefix="tokens-report")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  let sessions = "\{dir}/sessions"
  @fs.mkdir("\{projects}/p/s1/subagents", recursive=true)
  @fs.mkdir("\{sessions}/2026/10/28", recursive=true)
  @fs.write_file(
    "\{projects}/p/s1.jsonl",
    (
      #|{"type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"m1","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":2,"cache_read_input_tokens":3,"output_tokens":4}}}
    ),
  )
  @fs.write_file(
    "\{projects}/p/s1/subagents/agent-a.jsonl",
    (
      #|{"type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":true,"message":{"id":"m2","content":[],"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10}}}
    ),
  )
  @fs.write_file(
    "\{sessions}/2026/10/28/rollout-c1.jsonl",
    (
      #|{"type":"token_usage_record","payload":{"response_id":"r1","usage":{"input_tokens":9,"cached_input_tokens":4,"cache_write_input_tokens":0,"output_tokens":1}}}
    ),
  )
  let matches = command(dir).parse(argv=[
    "--projects", projects, "--sessions", sessions,
  ])

  let output = report(matches, 7L * 86_400_000L)

  assert_true(output.contains("\"records\":3"))
  assert_true(
    output.contains(
      "\"total\":{\"responses\":3,\"input\":16,\"cache_creation\":2,\"cache_read\":7,\"output\":15,\"total\":40,\"sidechain_total\":20",
    ),
  )
  assert_true(output.contains("\"session\":\"rollout-c1\""))
}

///|
async test "tokens rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="tokens-options")
  defer @fs.rmdir(dir, recursive=true)
  let paths = ["--projects", "\{dir}/missing", "--sessions", "\{dir}/missing"]

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
