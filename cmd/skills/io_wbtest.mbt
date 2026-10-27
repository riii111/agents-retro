///|
async test "skills reads Claude Code and Codex logs and lists unused installed skills" {
  let dir = @fs.tmpdir(prefix="skills-report")
  defer @fs.rmdir(dir, recursive=true)
  let projects = "\{dir}/projects"
  let sessions = "\{dir}/sessions"
  let claude_skills = "\{dir}/claude-skills"
  let codex_skills = "\{dir}/codex-skills"
  @fs.mkdir("\{projects}/p/s1/subagents", recursive=true)
  @fs.mkdir("\{sessions}/2026/10/28", recursive=true)
  @fs.mkdir("\{claude_skills}/used", recursive=true)
  @fs.mkdir("\{claude_skills}/idle", recursive=true)
  @fs.mkdir("\{claude_skills}/not-a-skill", recursive=true)
  @fs.mkdir("\{codex_skills}/.system/hidden", recursive=true)
  @fs.mkdir("\{codex_skills}/idle-codex", recursive=true)
  @fs.write_file("\{claude_skills}/used/SKILL.md", "")
  @fs.write_file("\{claude_skills}/idle/SKILL.md", "")
  @fs.write_file("\{codex_skills}/.system/hidden/SKILL.md", "")
  @fs.write_file("\{codex_skills}/idle-codex/SKILL.md", "")
  @fs.write_file(
    "\{projects}/p/s1.jsonl",
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":false,"message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"used"}}]}}
    ),
  )
  @fs.write_file(
    "\{projects}/p/s1/subagents/agent-a.jsonl",
    (
      #|{"type":"assistant","sessionId":"s1","isSidechain":true,"message":{"id":"m2","content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"subagent_type":"Explore"}}]}}
    ),
  )
  @fs.write_file(
    "\{sessions}/2026/10/28/rollout-c1.jsonl",
    (
      #|{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"[$idle-codex](/x/idle-codex/SKILL.md)"}]}}
    ),
  )
  let matches = command(dir).parse(argv=[
    "--projects", projects, "--sessions", sessions, "--claude-skills", claude_skills,
    "--codex-skills", codex_skills,
  ])

  let output = report(matches, 7L * 86_400_000L)

  assert_true(output.contains("\"records\":3"))
  assert_true(output.contains("\"skill\":\"used\""))
  assert_true(output.contains("\"subagent_type\":\"Explore\""))
  assert_true(output.contains("\"sidechain_invocations\":1"))
  assert_true(
    output.contains(
      "\"unused_skills\":[{\"source\":\"claude\",\"skill\":\"idle\"}]}",
    ),
  )
  assert_false(output.contains("not-a-skill"))
  assert_false(output.contains("hidden"))
}

///|
async test "skills rejects negative numeric options and preserves zero" {
  let dir = @fs.tmpdir(prefix="skills-options")
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
