///|
fn log_lines() -> Array[String] {
  [
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cat README.md"}}]}}
    ),
    (
      #|{"type":"user","sessionId":"s1","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"PreToolUse:Bash hook error: Use bat instead of cat!\nExample: bat <file>"}]}}
    ),
    (
      #|{"type":"user","sessionId":"s1","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"PreToolUse:Bash hook error: Use bat instead of cat!\nExample: bat <file>"}]}}
    ),
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":true,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"cd /w && git add -f x"}}]}}
    ),
    (
      #|{"type":"user","sessionId":"s1","isSidechain":true,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t2","is_error":true,"content":[{"type":"text","text":"PreToolUse:Bash hook error: git add --force is blocked"}]}]}}
    ),
    (
      #|{"type":"assistant","sessionId":"s2","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t3","name":"Bash","input":{"command":"cat a.txt"}}]}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t3","is_error":true,"content":"PreToolUse:Bash hook error: Use bat instead of cat!\nExample: bat <file>"}]}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t4","is_error":true,"content":"PreToolUse:Write hook error: Edit the worktree copy"}]}}
    ),
    (
      #|{"type":"attachment","uuid":"a1","sessionId":"s2","isSidechain":false,"attachment":{"type":"hook_blocking_error","hookName":"Stop","hookEvent":"Stop","blockingError":{"blockingError":"Add the link.\nDetails","command":"check.py"}}}
    ),
    (
      #|{"type":"attachment","uuid":"a2","sessionId":"s2","isSidechain":false,"attachment":{"type":"hook_non_blocking_error","hookName":"PostToolUse:Edit","hookEvent":"PostToolUse"}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t5","is_error":true,"content":"Exit code 1\nthe hook error: not a block"}]}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t6","content":"PreToolUse:Bash hook error: quoted in a successful result"}]}}
    ),
  ]
}

///|
fn build_report() -> @hooks.Report {
  let report = @hooks.Report::new()
  let log = report.claude_log(session="file-stem")
  for line in log_lines() {
    log.read_line(line)
  }

  report
}

///|
test "report counts blocked operations by message, tool and command head" {
  let json = @json.parse(build_report().to_json(days=7L, records=2, limit=15))
  inspect(
    json.stringify(indent=2),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 2,
      #|  "total": {
      #|    "blocks": 5,
      #|    "sessions": 2,
      #|    "sidechain_blocks": 1
      #|  },
      #|  "messages": [
      #|    {
      #|      "event": "PreToolUse",
      #|      "message": "Use bat instead of cat!",
      #|      "blocks": 2,
      #|      "sessions": 2,
      #|      "sidechain_blocks": 0
      #|    },
      #|    {
      #|      "event": "PreToolUse",
      #|      "message": "git add --force is blocked",
      #|      "blocks": 1,
      #|      "sessions": 1,
      #|      "sidechain_blocks": 1
      #|    },
      #|    {
      #|      "event": "PreToolUse",
      #|      "message": "Edit the worktree copy",
      #|      "blocks": 1,
      #|      "sessions": 1,
      #|      "sidechain_blocks": 0
      #|    },
      #|    {
      #|      "event": "Stop",
      #|      "message": "Add the link.",
      #|      "blocks": 1,
      #|      "sessions": 1,
      #|      "sidechain_blocks": 0
      #|    }
      #|  ],
      #|  "tools": [
      #|    {
      #|      "event": "PreToolUse",
      #|      "tool": "Bash",
      #|      "blocks": 3,
      #|      "sessions": 2,
      #|      "sidechain_blocks": 1
      #|    },
      #|    {
      #|      "event": "PreToolUse",
      #|      "tool": "Write",
      #|      "blocks": 1,
      #|      "sessions": 1,
      #|      "sidechain_blocks": 0
      #|    }
      #|  ],
      #|  "commands": [
      #|    {
      #|      "tool": "Bash",
      #|      "command": "cat",
      #|      "blocks": 2,
      #|      "sessions": 2,
      #|      "sidechain_blocks": 0
      #|    },
      #|    {
      #|      "tool": "Bash",
      #|      "command": "git add",
      #|      "blocks": 1,
      #|      "sessions": 1,
      #|      "sidechain_blocks": 1
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "report limit keeps the most blocked entries" {
  let json = @json.parse(build_report().to_json(days=7L, records=2, limit=1))
  inspect(
    json.stringify(),
    content=(
      #|{"days":7,"records":2,"total":{"blocks":5,"sessions":2,"sidechain_blocks":1},"messages":[{"event":"PreToolUse","message":"Use bat instead of cat!","blocks":2,"sessions":2,"sidechain_blocks":0}],"tools":[{"event":"PreToolUse","tool":"Bash","blocks":3,"sessions":2,"sidechain_blocks":1}],"commands":[{"tool":"Bash","command":"cat","blocks":2,"sessions":2,"sidechain_blocks":0}]}
    ),
  )
}

///|
test "candidate lines cover hook errors, Stop blocks and Bash calls" {
  assert_true(@hooks.is_claude_candidate(b"x hook error: y"))
  assert_true(@hooks.is_claude_candidate(b"{\"type\":\"hook_blocking_error\"}"))
  assert_true(@hooks.is_claude_candidate(b"{\"name\":\"Bash\"}"))
  assert_false(@hooks.is_claude_candidate(b"{\"type\":\"assistant\"}"))
}
