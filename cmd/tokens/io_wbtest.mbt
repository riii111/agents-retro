///|
let test_now_ms : Int64 = 1_793_143_854_000L

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
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"m1","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":2,"cache_read_input_tokens":3,"output_tokens":4}}}
    ),
  )
  @fs.write_file(
    "\{projects}/p/s1/subagents/agent-a.jsonl",
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":true,"message":{"id":"m2","content":[],"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10}}}
    ),
  )
  @fs.write_file(
    "\{sessions}/2026/10/28/rollout-c1.jsonl",
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"token_usage_record","payload":{"response_id":"r1","usage":{"input_tokens":9,"cached_input_tokens":4,"cache_write_input_tokens":0,"output_tokens":1}}}
    ),
  )
  let matches = command(dir).parse(argv=[
    "--projects", projects, "--sessions", sessions,
  ])

  let output = report(matches, test_now_ms)

  assert_true(output.contains("\"records\":3"))
  assert_true(
    output.contains(
      "\"total\":{\"responses\":3,\"input\":16,\"cache_creation\":2,\"cache_read\":7,\"output\":15,\"total\":40,\"sidechain_total\":20",
    ),
  )
  assert_true(output.contains("\"session\":\"rollout-c1\""))
}

///|
async test "tokens leaves out usage dated before the period" {
  let dir = @fs.tmpdir(prefix="tokens-period")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  @fs.mkdir("\{projects}/p", recursive=true)
  @fs.write_file(
    "\{projects}/p/s1.jsonl",
    (
      #|{"timestamp":"2026-10-01T00:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"old","content":[],"usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1000}}}
      #|{"timestamp":"2026-10-27T00:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"fresh","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":2}}}
    ),
  )
  let matches = command(dir).parse(argv=[
    "--projects",
    projects,
    "--sessions",
    "\{dir}/missing",
  ])

  let output = report(matches, test_now_ms)

  assert_true(
    output.contains(
      "\"total\":{\"responses\":1,\"input\":1,\"cache_creation\":0,\"cache_read\":0,\"output\":2,\"total\":3",
    ),
  )
}

///|
async test "tokens compares the period start at millisecond precision" {
  let dir = @fs.tmpdir(prefix="tokens-boundary")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  @fs.mkdir("\{projects}/p", recursive=true)
  @fs.write_file(
    "\{projects}/p/s1.jsonl",
    (
      #|{"timestamp":"2026-10-20T23:30:54.036Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"before","content":[],"usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
      #|{"timestamp":"2026-10-20T23:30:54Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"whole-second","content":[],"usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
      #|{"timestamp":"2026-10-20T23:30:54.037Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"at","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
      #|{"timestamp":"2026-10-20T23:30:54.038Z","type":"assistant","sessionId":"s1","cwd":"/w","isSidechain":false,"message":{"id":"after","content":[],"usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
    ),
  )
  let matches = command(dir).parse(argv=[
    "--projects",
    projects,
    "--sessions",
    "\{dir}/missing",
  ])

  let output = report(matches, test_now_ms + 37L)

  assert_true(output.contains("\"total\":{\"responses\":2,\"input\":3,"))
}

///|
async test "tokens rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="tokens-options")
  defer @fs.rmdir(dir, recursive=true)
  let paths = ["--projects", "\{dir}/missing", "--sessions", "\{dir}/missing"]

  for args in [["--days", "-1"], ["--limit=-1"]] {
    let options = command(dir).parse(argv=paths + args)

    let error = try {
      ignore(report(options, 0L))
      ""
    } catch {
      err => err.to_string()
    }

    assert_true(error.contains("must be non-negative"))
  }

  let options = command(dir).parse(argv=paths + ["--days", "0", "--limit", "0"])

  ignore(report(options, 0L))
}
