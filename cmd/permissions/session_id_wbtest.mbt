///|
test "a subagent log belongs to the session that started it" {
  assert_eq(session_id("/p/proj/abc.jsonl"), "abc")
  assert_eq(session_id("/p/proj/abc/subagents/agent-1.jsonl"), "abc")
  assert_eq(session_id("subagents/agent-1.jsonl"), "agent-1")
  assert_eq(session_id("agent-1.jsonl"), "agent-1")
}
