///|
test "claude_messages keeps user turns only" {
  let log =
    #|{"type":"user","timestamp":"2026-10-20T01:00:00.000Z","cwd":"/w","message":{"content":"hello"}}
    #|{"type":"assistant","message":{"content":"hi"}}
    #|{"type":"user","isMeta":true,"message":{"content":"meta"}}
    #|{"type":"user","isSidechain":true,"message":{"content":"side"}}
    #|not json
    #|{"type":"user","message":{"content":[{"type":"text","text":"a"},{"type":"image"},{"type":"text","text":"b"}]}}
    #|{"type":"user","message":{"content":"   "}}
  let rows = @retro.claude_messages(log, project="-Users-me-repo", session="s1")
  assert_eq(rows.map(r => r.raw), ["hello", "a b"])
  assert_eq(rows[0].role, "main")
  assert_eq(rows[0].cwd, "/w")
  assert_eq(rows[1].ts, "")
}

///|
test "claude_messages marks codex worktrees as worker" {
  let log =
    #|{"type":"user","message":{"content":"x"}}
  let rows = @retro.claude_messages(
    log,
    project="-Users-me--codex-worktrees-abc",
    session="s",
  )
  assert_eq(rows[0].role, "worker")
}

///|
test "codex_messages follows the thread source" {
  let log =
    #|{"type":"response_item","payload":{"role":"user","content":[{"text":"before meta"}]}}
    #|{"type":"session_meta","payload":{"thread_source":"agent_created_thread","cwd":"/w"}}
    #|{"type":"response_item","timestamp":"t1","payload":{"role":"user","content":[{"text":"a"},{"text":"b"}]}}
    #|{"type":"response_item","payload":{"role":"assistant","content":[{"text":"reply"}]}}
    #|{"type":"session_meta","payload":{"thread_source":"subagent"}}
    #|{"type":"response_item","payload":{"role":"user","content":[{"text":"hidden"}]}}
  let rows = @retro.codex_messages(log, session="s")
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].raw, "a b")
  assert_eq(rows[0].role, "worker")
  assert_eq(rows[0].cwd, "/w")
}
