///|
fn summary_metrics() -> @messages.Metrics {
  {
    since: "s",
    messages: 3,
    sessions: 2,
    delegated: 1,
    by_role: [("claude/main", 2), ("codex/user", 1)],
    unmatched: 1,
    patterns: [
      { name: "review", messages: 2, sessions: 1, },
      { name: "new", messages: 1, sessions: 1, },
    ],
  }
}

///|
test "format_summary without a previous run" {
  let expected =
    #|Owner messages: 3 in 2 sessions (agent-to-agent messages excluded: 1)
    #|  claude/main: 2
    #|  codex/user: 1
    #|
    #|Patterns (messages / sessions)
    #|  review: 2 / 1
    #|  new: 1 / 1
    #|
    #|Unmatched by any pattern: 1
    #|
    #|Examples: o/e.tsv
    #|Unmatched: o/u-01.tsv
    #|Messages (full text, line number = id): o/m.tsv
  assert_eq(
    @messages.format_summary(
      summary_metrics(),
      None,
      examples_path="o/e.tsv",
      unmatched_paths=["o/u-01.tsv"],
      messages_path="o/m.tsv",
    ),
    expected.trim_end(chars="\n").to_owned(),
  )
}

///|
test "format_summary compares with the previous run" {
  let previous : @messages.PreviousMetrics = {
    date: "2026-10-17",
    patterns: { "review": { name: "review", messages: 5, sessions: 3, } },
  }
  let summary = @messages.format_summary(
    summary_metrics(),
    Some(previous),
    examples_path="o/e.tsv",
    unmatched_paths=[],
    messages_path="o/m.tsv",
  )
  assert_true(
    summary.contains("Patterns (messages / sessions)  vs 2026-10-17\n"),
  )
  assert_true(summary.contains("  review: 2 / 1  (was 5 / 3)\n"))
  assert_true(summary.contains("  new: 1 / 1\n"))
  assert_false(summary.contains("Unmatched: "))
}
