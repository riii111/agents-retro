///|
fn claude_lines() -> Array[String] {
  [
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":false,"message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"create-pr"}}]}}
    ),
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":false,"message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"create-pr"}}]}}
    ),
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":false,"message":{"id":"m2","content":[{"type":"tool_use","id":"t2","name":"Skill","input":{"skill":"plug:cr"}},{"type":"tool_use","id":"t3","name":"Agent","input":{"description":"d","subagent_type":"Explore"}}]}}
    ),
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":true,"message":{"id":"m3","content":[{"type":"tool_use","id":"t4","name":"Agent","input":{"subagent_type":"Explore"}},{"type":"tool_use","id":"t5","name":"Agent","input":{"description":"no type"}}]}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":"<command-name>/create-pr</command-name>\n<command-message>create-pr</command-message>\n<command-args></command-args>"}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"<command-message>exit</command-message>\n<command-name>/exit</command-name>"}]}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":"please run <command-name>/create-pr</command-name>"}}
    ),
    (
      #|{"type":"user","sessionId":"s2","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"<command-name>/create-pr</command-name>"}]}}
    ),
  ]
}

///|
fn codex_lines() -> Array[String] {
  [
    (
      #|{"type":"session_meta","payload":{"id":"c1","cwd":"/w","source":"vscode"}}
    ),
    (
      #|{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"[$task-worker](/home/me/.codex/skills/task-worker/SKILL.md) then [$task-worker](/x/task-worker/SKILL.md) and [$s](SKILL.md) [$name](/absolute/path/SKILL.md) [$ broken"}]}}
    ),
    (
      #|{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"[$task-worker](/x/task-worker/SKILL.md)"}]}}
    ),
    (
      #|{"type":"session_meta","payload":{"id":"c2","source":{"subagent":{"other":"guardian"}}}}
    ),
    (
      #|{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"[$ai-code-review](/x/ai-code-review/SKILL.md)"}]}}
    ),
  ]
}

///|
fn build_report() -> @skills.Report {
  let report = @skills.Report::new()
  let claude = report.claude_log(session="file-stem")
  for line in claude_lines() {
    claude.read_line(line)
  }
  let codex = report.codex_log(session="file-stem")
  for line in codex_lines() {
    codex.read_line(line)
  }

  report
}

///|
test "report counts skills by how they were called and lists unused ones" {
  let json = @json.parse(
    build_report().to_json(
      days=7L,
      records=3,
      limit=15,
      claude_skills=["cr", "create-pr", "lt-builder"],
      codex_skills=["ai-code-review", "explore", "task-worker"],
    ),
  )
  inspect(
    json.stringify(indent=2),
    content=(
      #|{
      #|  "days": 7,
      #|  "records": 3,
      #|  "skills": [
      #|    {
      #|      "source": "codex",
      #|      "skill": "task-worker",
      #|      "via": "mention",
      #|      "installed": true,
      #|      "invocations": 2,
      #|      "sidechain_invocations": 0,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "source": "claude",
      #|      "skill": "create-pr",
      #|      "via": "skill_tool",
      #|      "installed": true,
      #|      "invocations": 1,
      #|      "sidechain_invocations": 0,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "source": "claude",
      #|      "skill": "plug:cr",
      #|      "via": "skill_tool",
      #|      "installed": true,
      #|      "invocations": 1,
      #|      "sidechain_invocations": 0,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "source": "claude",
      #|      "skill": "create-pr",
      #|      "via": "slash_command",
      #|      "installed": true,
      #|      "invocations": 1,
      #|      "sidechain_invocations": 0,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "source": "claude",
      #|      "skill": "exit",
      #|      "via": "slash_command",
      #|      "installed": false,
      #|      "invocations": 1,
      #|      "sidechain_invocations": 0,
      #|      "sessions": 1
      #|    },
      #|    {
      #|      "source": "codex",
      #|      "skill": "ai-code-review",
      #|      "via": "mention",
      #|      "installed": true,
      #|      "invocations": 1,
      #|      "sidechain_invocations": 1,
      #|      "sessions": 1
      #|    }
      #|  ],
      #|  "subagents": [
      #|    {
      #|      "source": "claude",
      #|      "subagent_type": "Explore",
      #|      "invocations": 2,
      #|      "sidechain_invocations": 1,
      #|      "sessions": 1
      #|    }
      #|  ],
      #|  "unused_skills": [
      #|    {
      #|      "source": "claude",
      #|      "skill": "lt-builder"
      #|    },
      #|    {
      #|      "source": "codex",
      #|      "skill": "explore"
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "report limits used lists but keeps every unused skill" {
  let json = @json.parse(
    build_report().to_json(
      days=7L,
      records=3,
      limit=1,
      claude_skills=["a", "b"],
      codex_skills=[],
    ),
  )
  guard json is Object(report) &&
    report["skills"] is Array(skills) &&
    report["subagents"] is Array(subagents) &&
    report["unused_skills"] is Array(unused) else {
    fail("report has an unexpected shape")
  }

  inspect(skills.length(), content="1")
  inspect(subagents.length(), content="1")
  inspect(unused.length(), content="2")
}
