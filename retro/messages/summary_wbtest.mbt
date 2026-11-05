///|
fn summary_metrics() -> Metrics {
  {
    since: "s",
    messages: 3,
    sessions: 2,
    delegated: 1,
    by_role: [("claude/main", 2), ("codex/user", 1)],
    unmatched: 1,
    period: None,
    detailed: false,
    apps: [],
    weeks: [],
    candidates: [],
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
    format_summary(
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
  let previous : PreviousMetrics = {
    date: "2026-10-17",
    patterns: { "review": { name: "review", messages: 5, sessions: 3, } },
    period: None,
    candidates: {},
  }

  let summary = format_summary(
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

///|
fn period_summary(
  previous : PreviousMetrics?,
  candidates~ : Array[CandidateCount] = [],
  weeks~ : Array[Week] = [],
  apps~ : Array[AppCount] = [],
) -> String {
  format_summary(
    {
      ..summary_metrics(),
      period: Some(Period::utc(days=7L, until_ms=1_792_551_600_000L)),
      detailed: true,
      candidates,
      weeks,
      apps,
    },
    previous,
    examples_path="o/e.tsv",
    unmatched_paths=[],
    messages_path="o/m.tsv",
  )
}

///|
fn previous_with(period : Period?) -> PreviousMetrics {
  {
    date: "2026-10-14",
    patterns: { "review": { name: "review", messages: 5, sessions: 3, } },
    period,
    candidates: {},
  }
}

///|
test "format_summary states the period and total sessions" {
  let summary = period_summary(None)

  assert_true(
    summary.contains(
      "Period: last 7 days until 2026-10-21T03:00:00+00:00 (UTC; weeks start Monday 00:00)\n",
    ),
  )
  assert_true(
    summary.contains("Patterns (messages / sessions, 2 sessions in period)\n"),
  )
}

///|
test "format_summary compares only with a run over the same period" {
  let now = Period::utc(days=7L, until_ms=1_792_551_600_000L)

  let same = period_summary(Some(previous_with(Some({ ..now, until: "x", }))))
  assert_true(same.contains("sessions in period)  vs 2026-10-14\n"))
  assert_true(same.contains("  review: 2 / 1  (was 5 / 3)\n"))

  for
    previous in [
      previous_with(Some({ ..now, days: 14L, })),
      previous_with(None),
    ] {
    let summary = period_summary(Some(previous))

    assert_true(
      summary.contains(
        "  vs 2026-10-14: not compared (that run covered a different or unknown period)\n",
      ),
    )
    assert_false(summary.contains("was 5 / 3"))
  }
}

///|
test "format_summary lists candidates apart from patterns and weeks by app" {
  let candidates : Array[CandidateCount] = [
    {
      name: "fresh",
      messages: 2,
      sessions: 2,
      outside_patterns: 2,
      first_seen: "2026-10-21",
      seen_before: false,
    },
    {
      name: "old",
      messages: 4,
      sessions: 3,
      outside_patterns: 1,
      first_seen: "2026-10-07",
      seen_before: true,
    },
  ]
  let now = Period::utc(days=7L, until_ms=1_792_551_600_000L)
  let previous = {
    ..previous_with(Some(now)),
    candidates: {
      "old": {
        name: "old",
        messages: 1,
        sessions: 1,
        outside_patterns: 1,
        first_seen: "2026-10-07",
        seen_before: true,
      },
    },
  }
  let week : Week = {
    start: "2026-10-19",
    end: "2026-10-25",
    partial: true,
    covers_from: "2026-10-19T00:00:00Z",
    covers_until: "2026-10-21T03:00:00Z",
    sessions: 1,
    apps: [
      {
        app: "claude",
        messages: 2,
        sessions: 1,
        patterns: [{ name: "review", messages: 2, sessions: 1, }],
      },
    ],
  }

  let whole : AppCount = {
    app: "claude",
    messages: 3,
    sessions: 2,
    patterns: [{ name: "review", messages: 3, sessions: 2, }],
  }
  let summary = period_summary(Some(previous), candidates~, weeks=[week], apps=[
    whole,
  ])

  let expected =
    #|Candidates (messages / sessions; not part of the patterns)
    #|  fresh: 2 / 2  (new; 2 messages outside the patterns)
    #|  old: 4 / 3  (tracked since 2026-10-07, was 1 / 1; 1 messages outside the patterns)
    #|
    #|Unmatched by any pattern: 1
    #|
    #|By app, whole period (messages / sessions per pattern)
    #|  claude: 3 messages in 2 sessions
    #|    review: 3 / 2
    #|
    #|Weekly by app (messages / sessions per pattern)
    #|2026-10-19 to 2026-10-25: 1 sessions (partial week: covers 2026-10-19T00:00:00Z until 2026-10-21T03:00:00Z)
    #|  claude: 2 messages in 1 sessions
    #|    review: 2 / 1
    #|
    #|Examples:

  assert_true(summary.contains(expected.trim_end(chars="\n").to_owned()))

  let unaligned = period_summary(
    Some(previous_with(Some({ ..now, days: 30L, }))),
    candidates~,
  )

  assert_true(
    unaligned.contains("  old: 4 / 3  (tracked since 2026-10-07; 1 messages"),
  )
}

///|
test "format_summary without detail still refuses an unaligned comparison" {
  let now = Period::utc(days=7L, until_ms=1_792_551_600_000L)
  let metrics = { ..summary_metrics(), period: Some(now), }
  fn render(previous : PreviousMetrics) -> String {
    format_summary(
      metrics,
      Some(previous),
      examples_path="e",
      unmatched_paths=[],
      messages_path="m",
    )
  }

  let same = render(previous_with(Some({ ..now, until: "x", })))
  assert_true(same.contains("Patterns (messages / sessions)  vs 2026-10-14\n"))
  assert_true(same.contains("(was 5 / 3)"))
  assert_false(same.contains("Period:"))

  for
    previous in [
      previous_with(Some({ ..now, days: 21L, })),
      previous_with(None),
    ] {
    let summary = render(previous)

    assert_true(summary.contains("not compared"))
    assert_false(summary.contains("was 5 / 3"))
  }
}
