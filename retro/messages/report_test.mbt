///|
fn msg(id : Int32, text : String, session~ : String) -> @messages.Message {
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
fn review_hits(
  messages : Array[@messages.Message],
) -> Array[@messages.PatternHits] raise {
  let source =
    #|{"review": "CR|CodeRabbit", "conflict": "コンフリクト"}
  @messages.match_patterns(messages, @messages.parse_patterns(source))
}

///|
test "count_patterns counts messages and distinct sessions" {
  let hits = review_hits([
    msg(1, "CRきた", session="a"),
    msg(2, "CodeRabbitの指摘", session="a"),
    msg(3, "CR", session="b"),
    msg(4, "続けて", session="c"),
  ])
  assert_eq(
    @messages.count_patterns(hits).map((c : @messages.PatternCount) => {
      (c.name, c.messages, c.sessions)
    }),
    [("review", 3, 2), ("conflict", 0, 0)],
  )
}

///|
test "pattern_examples takes up to three messages from distinct sessions" {
  let hits = review_hits([
    msg(1, "CR 1", session="a"),
    msg(2, "CR 2", session="a"),
    msg(3, "CR 3", session="b"),
    msg(4, "CR 4", session="c"),
    msg(5, "CR 5", session="d"),
  ])
  assert_eq(@messages.pattern_examples(hits).map(e => (e.0, e.1.id)), [
    ("review", 1),
    ("review", 3),
    ("review", 4),
  ])
}

///|
test "unmatched_chunks keeps unmatched messages in order, 100 per chunk" {
  let messages = Array::makei(250, i => {
    let id = i + 1
    msg(id, if id % 5 == 0 { "CR" } else { "other" }, session="s")
  })
  let chunks = @messages.unmatched_chunks(messages, review_hits(messages))
  assert_eq(chunks.map(c => c.length()), [100, 100])
  assert_eq(chunks[0][0].id, 1)
  assert_eq(chunks[0][4].id, 6)
  assert_eq(@messages.unmatched_chunks([], review_hits([])).length(), 0)
}

///|
test "count_by_role sorts keys lexicographically" {
  let messages = [
    { ..msg(1, "a", session="s"), app: "codex", role: "user", },
    { ..msg(2, "b", session="s"), app: "claude", role: "worker", },
    { ..msg(3, "c", session="s"), app: "claude", role: "main", },
    { ..msg(4, "d", session="s"), app: "claude", role: "main", },
  ]
  assert_eq(@messages.count_by_role(messages), [
    ("claude/main", 2),
    ("claude/worker", 1),
    ("codex/user", 1),
  ])
}

///|
test "message_tsv_line" {
  assert_eq(
    @messages.message_tsv_line(msg(7, "  a\n\tb\u{3000}c  ", session="s")),
    "7\t2026-10-20T01:23\tcodex\tuser\ts\t/w\ta b c",
  )
}

///|
test "previews keep short text whole and cut long text to head and tail" {
  assert_eq(
    @messages.example_tsv_line("review", msg(7, " a\nb ", session="s")),
    "review\t7\ts\ta b",
  )
  let head = "あ".repeat(140)
  let tail = "い".repeat(60)
  let long = msg(8, head + "う".repeat(100) + tail, session="s")
  assert_eq(
    @messages.unmatched_tsv_line(long),
    "8\t\{head} …[300字]… \{tail}",
  )
  let limit = msg(9, "え".repeat(200), session="s")
  assert_eq(@messages.unmatched_tsv_line(limit), "9\t\{"え".repeat(200)}")
}
