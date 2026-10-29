///|
let test_since : String = "2026-10-20T00:00:00"

///|
fn claude_lines() -> Array[String] {
  [
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u0","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":"start"}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","uuid":"a1","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m1","role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git -C /x status"}}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u1","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"clean"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","uuid":"a2","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m2","role":"assistant","content":[{"type":"tool_use","id":"t2","name":"Edit","input":{"file_path":"/x"}}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u2","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t2","content":"The user doesn't want to proceed with this tool use. The tool use was rejected.","is_error":true}]},"toolDenialKind":"user-rejected"}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u3","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u4","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":"again"}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"assistant","uuid":"a3","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m3","role":"assistant","content":[{"type":"tool_use","id":"t3","name":"Bash","input":{"command":"cargo test --all"}}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u5","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]\n"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u6","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"u7","sessionId":"s1","cwd":"/work/a","isSidechain":true,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
    ),
  ]
}

///|
fn ignored_lines() -> Array[String] {
  [
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"i1","sessionId":"s2","cwd":"/work/b","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"none","content":"Exit code 1","is_error":true}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"i2","sessionId":"s2","cwd":"/work/b","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"none","content":"[Request interrupted by user]"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"i3","sessionId":"s2","cwd":"/work/b","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"why do I see [Request interrupted by user] here?"}]}}
    ),
    (
      #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"i4","sessionId":"s2","cwd":"/work/b","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"none","content":"The user doesn't want to take this action right now.","is_error":false}]}}
    ),
    "not json",
  ]
}

///|
fn build_report(lines : Array[Array[String]]) -> @interrupts.Report {
  let report = @interrupts.Report::new()
  for file in lines {
    let log = report.claude_log(since=test_since)
    for line in file {
      log.read_line(line)
    }
  }

  report
}

///|
test "report counts interruptions and rejections with the preceding tool call" {
  let report = build_report([claude_lines()])
  let json = @json.parse(report.to_json(days=7L, records=1, limit=15))
  inspect(
    json.stringify(indent=2),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 1,
      #|  "total": {
      #|    "interrupts": 3,
      #|    "tool_use_interrupts": 1,
      #|    "rejections": 1,
      #|    "total": 5,
      #|    "sidechain_total": 1
      #|  },
      #|  "projects": [
      #|    {
      #|      "project": "/work/a",
      #|      "sessions": 1,
      #|      "interrupts": 3,
      #|      "tool_use_interrupts": 1,
      #|      "rejections": 1,
      #|      "total": 5,
      #|      "sidechain_total": 1
      #|    }
      #|  ],
      #|  "sessions": [
      #|    {
      #|      "session": "s1",
      #|      "project": "/work/a",
      #|      "sidechain": false,
      #|      "tools": [
      #|        {
      #|          "tool": "Edit",
      #|          "command": "",
      #|          "interrupts": 0,
      #|          "tool_use_interrupts": 1,
      #|          "rejections": 1,
      #|          "total": 2,
      #|          "sidechain_total": 0
      #|        },
      #|        {
      #|          "tool": "Bash",
      #|          "command": "cargo test",
      #|          "interrupts": 1,
      #|          "tool_use_interrupts": 0,
      #|          "rejections": 0,
      #|          "total": 1,
      #|          "sidechain_total": 0
      #|        },
      #|        {
      #|          "tool": "(no tool call)",
      #|          "command": "",
      #|          "interrupts": 1,
      #|          "tool_use_interrupts": 0,
      #|          "rejections": 0,
      #|          "total": 1,
      #|          "sidechain_total": 0
      #|        }
      #|      ],
      #|      "interrupts": 2,
      #|      "tool_use_interrupts": 1,
      #|      "rejections": 1,
      #|      "total": 4,
      #|      "sidechain_total": 0
      #|    },
      #|    {
      #|      "session": "s1",
      #|      "project": "/work/a",
      #|      "sidechain": true,
      #|      "tools": [
      #|        {
      #|          "tool": "(no tool call)",
      #|          "command": "",
      #|          "interrupts": 1,
      #|          "tool_use_interrupts": 0,
      #|          "rejections": 0,
      #|          "total": 1,
      #|          "sidechain_total": 1
      #|        }
      #|      ],
      #|      "interrupts": 1,
      #|      "tool_use_interrupts": 0,
      #|      "rejections": 0,
      #|      "total": 1,
      #|      "sidechain_total": 1
      #|    }
      #|  ],
      #|  "tools": [
      #|    {
      #|      "tool": "Edit",
      #|      "command": "",
      #|      "interrupts": 0,
      #|      "tool_use_interrupts": 1,
      #|      "rejections": 1,
      #|      "total": 2,
      #|      "sidechain_total": 0
      #|    },
      #|    {
      #|      "tool": "(no tool call)",
      #|      "command": "",
      #|      "interrupts": 2,
      #|      "tool_use_interrupts": 0,
      #|      "rejections": 0,
      #|      "total": 2,
      #|      "sidechain_total": 1
      #|    },
      #|    {
      #|      "tool": "Bash",
      #|      "command": "cargo test",
      #|      "interrupts": 1,
      #|      "tool_use_interrupts": 0,
      #|      "rejections": 0,
      #|      "total": 1,
      #|      "sidechain_total": 0
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "report ignores text that only mentions an interruption" {
  let report = build_report([ignored_lines()])
  let json = @json.parse(report.to_json(days=7L, records=1, limit=15))
  inspect(
    json.stringify(indent=2),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 1,
      #|  "total": {
      #|    "interrupts": 0,
      #|    "tool_use_interrupts": 0,
      #|    "rejections": 0,
      #|    "total": 0,
      #|    "sidechain_total": 0
      #|  },
      #|  "projects": [],
      #|  "sessions": [],
      #|  "tools": []
      #|}
    ),
  )
}

///|
test "report counts a record copied into a resumed session once" {
  let report = build_report([claude_lines(), claude_lines()])
  let json = @json.parse(report.to_json(days=7L, records=2, limit=15))
  guard json is Object(root) && root.get("total") is Some(Object(total)) else {
    fail("missing total")
  }

  assert_true(total.get("total") is Some(Number(5, ..)))
}

///|
test "report counts only events dated in the period and keeps the earlier tool call" {
  let report = @interrupts.Report::new()
  let log = report.claude_log(since=test_since)
  for
    line in [
      (
        #|{"timestamp":"2026-10-01T10:00:00.000Z","type":"user","uuid":"o1","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
      ),
      (
        #|{"timestamp":"2026-10-01T10:00:01.000Z","type":"assistant","uuid":"o2","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"id":"m1","role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cargo test --all"}}]}}
      ),
      (
        #|{"timestamp":"2026-10-01T10:00:02.000Z","type":"user","uuid":"o3","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"The user doesn't want to proceed with this tool use.","is_error":true}]}}
      ),
      (
        #|{"timestamp":"2026-10-27T10:00:00.000Z","type":"user","uuid":"n1","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}
      ),
      (
        #|{"type":"user","uuid":"n2","sessionId":"s1","cwd":"/work/a","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
      ),
    ] {
    log.read_line(line)
  }

  let output = report.to_json(days=7L, records=1, limit=15)
  assert_true(
    output.contains(
      "\"total\":{\"interrupts\":0,\"tool_use_interrupts\":1,\"rejections\":0,\"total\":1,\"sidechain_total\":0}",
    ),
  )
  assert_true(output.contains("\"tool\":\"Bash\",\"command\":\"cargo test\""))
}

///|
test "report limits every list" {
  let report = build_report([claude_lines()])
  let json = @json.parse(report.to_json(days=7L, records=1, limit=1))
  guard json is Object(root) &&
    root.get("tools") is Some(Array(tools)) &&
    root.get("sessions") is Some(Array(sessions)) else {
    fail("missing lists")
  }

  assert_eq(tools.length(), 1)
  assert_eq(sessions.length(), 1)
}
