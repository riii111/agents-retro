///|
let test_since : String = "2026-10-20T00:00:00"

///|
fn claude_lines() -> Array[String] {
  [
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":"start"}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m1","role":"assistant","content":[{"type":"thinking","thinking":""}],"usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":0,"output_tokens":10}}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m1","role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git -C /x status"}}],"usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":0,"output_tokens":10}}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"12345"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m2","role":"assistant","content":[{"type":"text","text":"ok"}],"usage":{"input_tokens":3,"cache_creation_input_tokens":0,"cache_read_input_tokens":300,"output_tokens":20}}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/work/a","isSidechain":true,"message":{"id":"m3","role":"assistant","content":[{"type":"text","text":"sub"}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":4}}}
    ),
  ]
}

///|
fn codex_lines() -> Array[String] {
  [
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"session_meta","payload":{"id":"c1","cwd":"/work/b","source":"vscode"}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"x1","input":"ls"}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"token_usage_record","payload":{"response_id":"r1","usage":{"input_tokens":50,"cached_input_tokens":20,"cache_write_input_tokens":0,"output_tokens":5}}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"token_usage_record","payload":{"response_id":"r1","usage":{"input_tokens":50,"cached_input_tokens":20,"cache_write_input_tokens":0,"output_tokens":5}}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"x1","output":[{"type":"input_text","text":"abc"},{"type":"input_text","text":"de"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"token_usage_record","payload":{"response_id":"r2","usage":{"input_tokens":80,"cached_input_tokens":50,"cache_write_input_tokens":0,"output_tokens":7}}}
    ),
  ]
}

///|
fn build_report() -> @tokens.Report {
  let report = @tokens.Report::new()
  let claude = report.claude_log(session="file-stem", since=test_since)
  for line in claude_lines() {
    claude.read_line(line)
  }
  let codex = report.codex_log(session="file-stem", since=test_since)
  for line in codex_lines() {
    codex.read_line(line)
  }

  report
}

///|
test "report counts repeated responses once and splits sessions and sidechains" {
  let json = @json.parse(build_report().to_json(days=7L, records=2, limit=15))
  inspect(
    json.stringify(indent=2),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 2,
      #|  "total": {
      #|    "responses": 5,
      #|    "input": 66,
      #|    "cache_creation": 100,
      #|    "cache_read": 370,
      #|    "output": 46,
      #|    "total": 582,
      #|    "sidechain_total": 5,
      #|    "cache_read_ratio": 0.69
      #|  },
      #|  "projects": [
      #|    {
      #|      "project": "/work/a",
      #|      "sessions": 1,
      #|      "responses": 3,
      #|      "input": 6,
      #|      "cache_creation": 100,
      #|      "cache_read": 300,
      #|      "output": 34,
      #|      "total": 440,
      #|      "sidechain_total": 5,
      #|      "cache_read_ratio": 0.739
      #|    },
      #|    {
      #|      "project": "/work/b",
      #|      "sessions": 1,
      #|      "responses": 2,
      #|      "input": 60,
      #|      "cache_creation": 0,
      #|      "cache_read": 70,
      #|      "output": 12,
      #|      "total": 142,
      #|      "sidechain_total": 0,
      #|      "cache_read_ratio": 0.538
      #|    }
      #|  ],
      #|  "sessions": [
      #|    {
      #|      "source": "claude",
      #|      "session": "s1",
      #|      "project": "/work/a",
      #|      "sidechain": false,
      #|      "responses": 2,
      #|      "input": 5,
      #|      "cache_creation": 100,
      #|      "cache_read": 300,
      #|      "output": 30,
      #|      "total": 435,
      #|      "sidechain_total": 0,
      #|      "cache_read_ratio": 0.741
      #|    },
      #|    {
      #|      "source": "codex",
      #|      "session": "c1",
      #|      "project": "/work/b",
      #|      "sidechain": false,
      #|      "responses": 2,
      #|      "input": 60,
      #|      "cache_creation": 0,
      #|      "cache_read": 70,
      #|      "output": 12,
      #|      "total": 142,
      #|      "sidechain_total": 0,
      #|      "cache_read_ratio": 0.538
      #|    },
      #|    {
      #|      "source": "claude",
      #|      "session": "s1",
      #|      "project": "/work/a",
      #|      "sidechain": true,
      #|      "responses": 1,
      #|      "input": 1,
      #|      "cache_creation": 0,
      #|      "cache_read": 0,
      #|      "output": 4,
      #|      "total": 5,
      #|      "sidechain_total": 5,
      #|      "cache_read_ratio": 0
      #|    }
      #|  ],
      #|  "previous_tools": [
      #|    {
      #|      "tool": "Bash",
      #|      "command": "git status",
      #|      "responses": 2,
      #|      "input": 4,
      #|      "cache_creation": 0,
      #|      "cache_read": 300,
      #|      "output": 24,
      #|      "total": 328,
      #|      "sidechain_total": 5,
      #|      "cache_read_ratio": 0.987
      #|    },
      #|    {
      #|      "tool": "(user prompt)",
      #|      "command": "",
      #|      "responses": 2,
      #|      "input": 32,
      #|      "cache_creation": 100,
      #|      "cache_read": 20,
      #|      "output": 15,
      #|      "total": 167,
      #|      "sidechain_total": 0,
      #|      "cache_read_ratio": 0.132
      #|    },
      #|    {
      #|      "tool": "exec",
      #|      "command": "",
      #|      "responses": 1,
      #|      "input": 30,
      #|      "cache_creation": 0,
      #|      "cache_read": 50,
      #|      "output": 7,
      #|      "total": 87,
      #|      "sidechain_total": 0,
      #|      "cache_read_ratio": 0.625
      #|    }
      #|  ],
      #|  "tool_results": [
      #|    {
      #|      "tool": "exec",
      #|      "command": "",
      #|      "results": 1,
      #|      "chars": 6
      #|    },
      #|    {
      #|      "tool": "Bash",
      #|      "command": "git status",
      #|      "results": 1,
      #|      "chars": 5
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "report limits each list" {
  let json = @json.parse(build_report().to_json(days=7L, records=2, limit=1))
  inspect(
    json.stringify(indent=2),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 2,
      #|  "total": {
      #|    "responses": 5,
      #|    "input": 66,
      #|    "cache_creation": 100,
      #|    "cache_read": 370,
      #|    "output": 46,
      #|    "total": 582,
      #|    "sidechain_total": 5,
      #|    "cache_read_ratio": 0.69
      #|  },
      #|  "projects": [
      #|    {
      #|      "project": "/work/a",
      #|      "sessions": 1,
      #|      "responses": 3,
      #|      "input": 6,
      #|      "cache_creation": 100,
      #|      "cache_read": 300,
      #|      "output": 34,
      #|      "total": 440,
      #|      "sidechain_total": 5,
      #|      "cache_read_ratio": 0.739
      #|    }
      #|  ],
      #|  "sessions": [
      #|    {
      #|      "source": "claude",
      #|      "session": "s1",
      #|      "project": "/work/a",
      #|      "sidechain": false,
      #|      "responses": 2,
      #|      "input": 5,
      #|      "cache_creation": 100,
      #|      "cache_read": 300,
      #|      "output": 30,
      #|      "total": 435,
      #|      "sidechain_total": 0,
      #|      "cache_read_ratio": 0.741
      #|    }
      #|  ],
      #|  "previous_tools": [
      #|    {
      #|      "tool": "Bash",
      #|      "command": "git status",
      #|      "responses": 2,
      #|      "input": 4,
      #|      "cache_creation": 0,
      #|      "cache_read": 300,
      #|      "output": 24,
      #|      "total": 328,
      #|      "sidechain_total": 5,
      #|      "cache_read_ratio": 0.987
      #|    }
      #|  ],
      #|  "tool_results": [
      #|    {
      #|      "tool": "exec",
      #|      "command": "",
      #|      "results": 1,
      #|      "chars": 6
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "report counts a tool result copied into a resumed file once" {
  let report = @tokens.Report::new()
  let original = report.claude_log(session="original", since=test_since)
  for
    line in [
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Read","input":{}},{"type":"tool_use","id":"t2","name":"Read","input":{}}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","cwd":"/w","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"abc"}]}}
      ),
    ] {
    original.read_line(line)
  }
  let resumed = report.claude_log(session="resumed", since=test_since)
  for
    line in [
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Read","input":{}},{"type":"tool_use","id":"t2","name":"Read","input":{}}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","cwd":"/w","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"abc"}]}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","cwd":"/w","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t2","content":"de"}]}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","message":{"id":"m2","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}
      ),
    ] {
    resumed.read_line(line)
  }

  let output = report.to_json(days=7L, records=2, limit=15)
  assert_true(output.contains("\"total\":{\"responses\":2,"))
  assert_true(
    output.contains(
      "\"tool_results\":[{\"tool\":\"Read\",\"command\":\"\",\"results\":2,\"chars\":5}]",
    ),
  )
  assert_true(
    output.contains("{\"tool\":\"Read\",\"command\":\"\",\"responses\":1,"),
  )
}

///|
test "report counts only Claude records dated in the period and keeps earlier calls" {
  let report = @tokens.Report::new()
  let claude = report.claude_log(session="file-stem", since=test_since)
  for
    line in [
      (
        #|{"timestamp":"2026-10-01T10:00:00.000Z","type":"assistant","sessionId":"s1","cwd":"/w","message":{"id":"old1","content":[{"type":"tool_use","id":"t1","name":"Read","input":{}},{"type":"tool_use","id":"t2","name":"Write","input":{}}],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100}}}
      ),
      (
        #|{"timestamp":"2026-10-01T10:00:01.000Z","type":"user","sessionId":"s1","cwd":"/w","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"old result"}]}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","sessionId":"s1","cwd":"/w","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t2","content":"new"}]}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:01.000Z","type":"assistant","sessionId":"s1","cwd":"/w","message":{"id":"new1","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":2}}}
      ),
      (
        #|{"type":"assistant","sessionId":"s1","cwd":"/w","message":{"id":"undated","content":[],"usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1000}}}
      ),
    ] {
    claude.read_line(line)
  }

  let output = report.to_json(days=7L, records=1, limit=15)
  assert_true(
    output.contains(
      "\"total\":{\"responses\":1,\"input\":1,\"cache_creation\":0,\"cache_read\":0,\"output\":2,\"total\":3,",
    ),
  )
  assert_true(
    output.contains(
      "\"tool_results\":[{\"tool\":\"Write\",\"command\":\"\",\"results\":1,\"chars\":3}]",
    ),
  )
  assert_true(
    output.contains(
      "\"previous_tools\":[{\"tool\":\"Write\",\"command\":\"\",\"responses\":1,",
    ),
  )
}

///|
test "report counts only Codex records dated in the period and keeps earlier calls" {
  let report = @tokens.Report::new()
  let codex = report.codex_log(session="file-stem", since=test_since)
  for
    line in [
      (
        #|{"timestamp":"2026-10-01T10:00:00.000Z","type":"session_meta","payload":{"id":"c1","cwd":"/work/b","source":"vscode"}}
      ),
      (
        #|{"timestamp":"2026-10-01T10:00:01.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","call_id":"x1"}}
      ),
      (
        #|{"timestamp":"2026-10-01T10:00:02.000Z","type":"token_usage_record","payload":{"response_id":"old1","usage":{"input_tokens":100,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":100}}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"x1","output":"new"}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:01.000Z","type":"token_usage_record","payload":{"response_id":"new1","usage":{"input_tokens":1,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":2}}}
      ),
    ] {
    codex.read_line(line)
  }

  let output = report.to_json(days=7L, records=1, limit=15)
  assert_true(
    output.contains(
      "\"total\":{\"responses\":1,\"input\":1,\"cache_creation\":0,\"cache_read\":0,\"output\":2,\"total\":3,",
    ),
  )
  assert_true(output.contains("\"project\":\"/work/b\""))
  assert_true(
    output.contains(
      "\"tool_results\":[{\"tool\":\"exec\",\"command\":\"\",\"results\":1,\"chars\":3}]",
    ),
  )
  assert_true(
    output.contains(
      "\"previous_tools\":[{\"tool\":\"exec\",\"command\":\"\",\"responses\":1,",
    ),
  )
}

///|
test "report keeps equal call ids from Claude and Codex apart across copied files" {
  let report = @tokens.Report::new()
  for file in ["a", "b"] {
    let claude = report.claude_log(session=file, since=test_since)
    for
      line in [
        (
          #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","message":{"id":"m1","content":[{"type":"tool_use","id":"same","name":"Read","input":{}}]}}
        ),
        (
          #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"same","content":"abc"}]}}
        ),
      ] {
      claude.read_line(line)
    }
    let codex = report.codex_log(session=file, since=test_since)
    for
      line in [
        (
          #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","call_id":"same"}}
        ),
        (
          #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"same","output":"de"}}
        ),
      ] {
      codex.read_line(line)
    }
  }

  let output = report.to_json(days=7L, records=4, limit=15)
  assert_true(
    output.contains(
      "\"tool_results\":[{\"tool\":\"Read\",\"command\":\"\",\"results\":1,\"chars\":3},{\"tool\":\"exec\",\"command\":\"\",\"results\":1,\"chars\":2}]",
    ),
  )
}
