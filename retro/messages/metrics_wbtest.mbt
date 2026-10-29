///|
fn sample_metrics() -> @messages.Metrics {
  {
    since: "2026-10-17T01:02:03.456000+00:00",
    messages: 3,
    sessions: 2,
    delegated: 1,
    by_role: [("claude/main", 2), ("codex/user", 1)],
    unmatched: 1,
    patterns: [
      { name: "review", messages: 2, sessions: 1, },
      { name: "引用\"と\\と\t", messages: 0, sessions: 0, },
    ],
  }
}

///|
test "to_json matches Python's json.dump with indent=1" {
  let expected =
    #|{
    #| "since": "2026-10-17T01:02:03.456000+00:00",
    #| "messages": 3,
    #| "sessions": 2,
    #| "delegated": 1,
    #| "by_role": {
    #|  "claude/main": 2,
    #|  "codex/user": 1
    #| },
    #| "unmatched": 1,
    #| "patterns": {
    #|  "review": {
    #|   "messages": 2,
    #|   "sessions": 1
    #|  },
    #|  "引用\"と\\と\t": {
    #|   "messages": 0,
    #|   "sessions": 0
    #|  }
    #| }
    #|}

  assert_eq(
    sample_metrics().to_json(),
    expected.trim_end(chars="\n").to_owned(),
  )
}

///|
test "to_json writes empty objects inline" {
  let empty : @messages.Metrics = {
    ..sample_metrics(),
    by_role: [],
    patterns: [],
  }

  assert_true(empty.to_json().contains(" \"by_role\": {},\n"))
  assert_true(empty.to_json().has_suffix(" \"patterns\": {}\n}"))
}

///|
test "parse_previous_metrics reads its own output" {
  let previous = @messages.parse_previous_metrics(
    sample_metrics().to_json(),
    date="2026-10-17",
  )

  guard previous is Some(p) else { fail("expected previous metrics") }
  assert_eq(p.date, "2026-10-17")

  guard p.patterns.get("review") is Some(review) else { fail("no review") }
  assert_eq((review.messages, review.sessions), (2, 1))
}

///|
test "parse_previous_metrics treats an empty object as no previous run" {
  assert_true(@messages.parse_previous_metrics("{}", date="d") is None)

  guard @messages.parse_previous_metrics("{\"messages\": 1}", date="d")
    is Some(p) else {
    fail("expected previous metrics")
  }
  assert_true(p.patterns.is_empty())
}
