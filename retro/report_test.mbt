///|
fn msg(id : Int32, text : String, session~ : String) -> @retro.Message {
  {
    id,
    ts: "2026-10-20T01:23:45.000Z",
    app: "codex",
    role: "user",
    session,
    cwd: "/w",
    text,
  }
}

///|
test "count_patterns counts messages and distinct sessions" {
  let source =
    #|{"review": "CR|CodeRabbit", "conflict": "コンフリクト"}
  let patterns = @retro.parse_patterns(source)
  let messages = [
    msg(1, "CRきた", session="a"),
    msg(2, "CodeRabbitの指摘", session="a"),
    msg(3, "CR", session="b"),
    msg(4, "続けて", session="c"),
  ]
  let counts = @retro.count_patterns(messages, patterns)
  assert_eq(
    counts.map((c : @retro.PatternCount) => (c.name, c.messages, c.sessions)),
    [("review", 3, 2), ("conflict", 0, 0)],
  )
}

///|
test "count_by_role sorts keys lexicographically" {
  let messages = [
    { ..msg(1, "a", session="s"), app: "codex", role: "user", },
    { ..msg(2, "b", session="s"), app: "claude", role: "worker", },
    { ..msg(3, "c", session="s"), app: "claude", role: "main", },
    { ..msg(4, "d", session="s"), app: "claude", role: "main", },
  ]
  assert_eq(@retro.count_by_role(messages), [
    ("claude/main", 2),
    ("claude/worker", 1),
    ("codex/user", 1),
  ])
}

///|
test "message_tsv_line" {
  assert_eq(
    @retro.message_tsv_line(msg(7, "  a\n\tb\u{3000}c  ", session="s")),
    "7\t2026-10-20T01:23\tcodex\tuser\ts\t/w\ta b c",
  )
}
