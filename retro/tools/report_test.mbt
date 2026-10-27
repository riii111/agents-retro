///|
fn use_line(
  id : String,
  name : String,
  input : String,
  session~ : String = "s1",
) -> String {
  "{\"type\":\"assistant\",\"sessionId\":\"\{session}\",\"isSidechain\":false,\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"\{id}\",\"name\":\"\{name}\",\"input\":\{input}}]}}"
}

///|
fn result_line(
  id : String,
  content : String,
  error~ : Bool,
  sidechain~ : Bool,
  session~ : String = "s1",
) -> String {
  "{\"type\":\"user\",\"sessionId\":\"\{session}\",\"isSidechain\":\{sidechain},\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"\{id}\",\"is_error\":\{error},\"content\":\"\{content}\"}]}}"
}

///|
fn failure_lines() -> Array[String] {
  [
    use_line("t1", "Bash", "{\"command\":\"cargo test -p a\"}"),
    result_line("t1", "Exit code 1", error=true, sidechain=false),
    use_line("t2", "Bash", "{\"command\":\"cargo test -p a\"}"),
    result_line("t2", "Exit code 1", error=true, sidechain=false),
    use_line("t3", "Bash", "{\"command\":\"cargo test -p b\"}"),
    result_line("t3", "Exit code 1", error=true, sidechain=true),
    use_line("t4", "Read", "{\"file_path\":\"/x\"}"),
    result_line("t4", "File does not exist.", error=true, sidechain=false),
    use_line("t5", "Bash", "{\"command\":\"ls\"}"),
    result_line("t5", "ok", error=false, sidechain=false),
    use_line("t6", "Bash", "{\"command\":\"cat x\"}"),
    result_line(
      "t6",
      "PreToolUse:Bash hook error: Use bat instead of cat!",
      error=true,
      sidechain=false,
    ),
    use_line("t7", "Edit", "{\"file_path\":\"/y\"}"),
    result_line(
      "t7",
      "The user doesn't want to proceed with this tool use.",
      error=true,
      sidechain=false,
    ),
    result_line("t8", "Exit code 2", error=true, sidechain=false),
  ]
}

///|
test "report counts failed calls by tool and command head and skips refusals" {
  let report = @tools.Report::new()
  let log = report.claude_log(session="file-stem")
  for line in failure_lines() {
    log.read_line(line)
  }

  inspect(
    @json.parse(report.to_json(days=7L, records=1, limit=15)).stringify(
      indent=2,
    ),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 1,
      #|  "total": {
      #|    "failures": 5,
      #|    "repeats": 1,
      #|    "sidechain_failures": 1,
      #|    "sessions": 1
      #|  },
      #|  "tools": [
      #|    {
      #|      "tool": "Bash",
      #|      "command": "cargo test",
      #|      "failures": 3,
      #|      "repeats": 1,
      #|      "sidechain_failures": 1,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "tool": "Read",
      #|      "command": "",
      #|      "failures": 1,
      #|      "repeats": 0,
      #|      "sidechain_failures": 0,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "tool": "(unknown)",
      #|      "command": "",
      #|      "failures": 1,
      #|      "repeats": 0,
      #|      "sidechain_failures": 0,
      #|      "sessions": 1
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
fn read_failure(
  report : @tools.Report,
  file~ : String,
  id~ : String,
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  let log = report.claude_log(session=file)
  log.read_line(use_line(id, "Bash", "{\"command\":\"make\"}", session~))
  log.read_line(
    result_line(id, "Exit code 1", error=true, sidechain~, session~),
  )
}

///|
test "report counts a repeated failure across the conversation and its subagent" {
  let report = @tools.Report::new()
  read_failure(report, file="s1", id="t1", session="s1", sidechain=false)
  read_failure(report, file="agent-a", id="t2", session="s1", sidechain=true)

  inspect(
    report.to_json(days=7L, records=2, limit=15),
    content=(
      #|{"days":7,"records":2,"total":{"failures":2,"repeats":1,"sidechain_failures":1,"sessions":1},"tools":[{"tool":"Bash","command":"make","failures":2,"repeats":1,"sidechain_failures":1,"sessions":1}]}
      #|
    ),
  )
}

///|
test "report does not count the same call in different sessions as a repeat" {
  let report = @tools.Report::new()
  read_failure(report, file="s1", id="t1", session="s1", sidechain=false)
  read_failure(report, file="s2", id="t2", session="s2", sidechain=false)

  inspect(
    report.to_json(days=7L, records=2, limit=15),
    content=(
      #|{"days":7,"records":2,"total":{"failures":2,"repeats":0,"sidechain_failures":0,"sessions":2},"tools":[{"tool":"Bash","command":"make","failures":2,"repeats":0,"sidechain_failures":0,"sessions":2}]}
      #|
    ),
  )
}

///|
test "report counts a copied tool use id once" {
  let report = @tools.Report::new()
  read_failure(report, file="s1", id="t1", session="s1", sidechain=false)
  read_failure(
    report,
    file="s1-resumed",
    id="t1",
    session="s1",
    sidechain=false,
  )

  inspect(
    report.to_json(days=7L, records=2, limit=15),
    content=(
      #|{"days":7,"records":2,"total":{"failures":1,"repeats":0,"sidechain_failures":0,"sessions":1},"tools":[{"tool":"Bash","command":"make","failures":1,"repeats":0,"sidechain_failures":0,"sessions":1}]}
      #|
    ),
  )
}

///|
test "report limits the tool list" {
  let report = @tools.Report::new()
  let log = report.claude_log(session="file-stem")
  for line in failure_lines() {
    log.read_line(line)
  }

  let json = @json.parse(report.to_json(days=7L, records=1, limit=1))
  inspect(
    json.stringify(),
    content=(
      #|{"days":7,"records":1,"total":{"failures":5,"repeats":1,"sidechain_failures":1,"sessions":1},"tools":[{"tool":"Bash","command":"cargo test","failures":3,"repeats":1,"sidechain_failures":1,"sessions":1}]}
    ),
  )
}

///|
test "candidate lines are tool uses and error results" {
  assert_true(@tools.is_claude_candidate(b"{\"type\":\"tool_use\"}"))
  assert_true(@tools.is_claude_candidate(b"{\"is_error\":true}"))
  assert_false(@tools.is_claude_candidate(b"{\"is_error\":false}"))
}
