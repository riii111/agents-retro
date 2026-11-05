///|
fn at(
  ts : String,
  id : Int32,
  app~ : String,
  session~ : String,
  text~ : String,
) -> Message {
  { id, ts, app, role: "main", session, cwd: "/w", text, }
}

///|
fn utc_ms(date : String, hour : Int64) -> Int64 {
  @clock.days_from_date(date).unwrap() * ms_per_day + hour * 3_600_000L
}

///|
fn sample_messages() -> Array[Message] {
  [
    at("2026-10-07T04:00:00.000Z", 1, app="claude", session="a", text="review"),
    at("2026-10-13T09:00:00.000Z", 2, app="claude", session="a", text="review"),
    at("2026-10-14T09:00:00.000Z", 3, app="codex", session="c", text="other"),
    at("2026-10-19T00:00:00.000Z", 4, app="claude", session="b", text="review"),
    at("2026-10-20T09:00:00.000Z", 5, app="claude", session="b", text="review"),
    at("2026-10-20T10:00:00.000Z", 6, app="claude", session="d", text="review"),
  ]
}

///|
test "weekly_breakdown splits UTC weeks at Monday 00:00 and marks cut weeks" {
  let messages = sample_messages()
  let weeks = weekly_breakdown(
    messages,
    match_patterns(messages, parse_patterns("{\"review\": \"review\"}")),
    since_ms=utc_ms("2026-10-07", 3),
    until_ms=utc_ms("2026-10-21", 3),
  )

  assert_eq(weeks.map(w => (w.start, w.end, w.partial, w.sessions)), [
    ("2026-10-05", "2026-10-11", true, 1),
    ("2026-10-12", "2026-10-18", false, 2),
    ("2026-10-19", "2026-10-25", true, 2),
  ])
  assert_eq(weeks[0].covers_from, "2026-10-07T03:00:00Z")
  assert_eq(weeks[0].covers_until, "2026-10-12T00:00:00Z")
  assert_eq(weeks[2].covers_until, "2026-10-21T03:00:00Z")

  // The message at exactly Monday 00:00 belongs to the new week.
  let last = weeks[2].apps
  assert_eq(last.map(a => (a.app, a.messages, a.sessions)), [("claude", 3, 2)])
  assert_eq(last[0].patterns.map(c => (c.name, c.messages, c.sessions)), [
    ("review", 3, 2),
  ])
  assert_eq(weeks[1].apps.map(a => (a.app, a.messages, a.patterns.length())), [
    ("claude", 1, 1),
    ("codex", 1, 0),
  ])
}

///|
test "weekly_breakdown keeps weeks without messages" {
  let weeks = weekly_breakdown(
    [],
    [],
    since_ms=utc_ms("2026-10-12", 0),
    until_ms=utc_ms("2026-10-26", 0),
  )

  assert_eq(weeks.map(w => (w.start, w.partial, w.sessions, w.apps.length())), [
    ("2026-10-12", false, 0, 0),
    ("2026-10-19", false, 0, 0),
    ("2026-10-26", true, 0, 0),
  ])
}

///|
test "a run compares only with a run measured over the same period" {
  let now = Period::utc(days=7L, until_ms=utc_ms("2026-10-21", 3))
  let earlier : Period = { ..now, until: "2026-10-14T03:00:00+00:00", }
  fn previous(period : Period?) -> PreviousMetrics? {
    Some({ date: "d", patterns: {}, period, candidates: {}, })
  }

  assert_true(comparable(Some(now), previous(Some(earlier))))
  assert_false(comparable(Some(now), previous(Some({ ..earlier, days: 14L, }))))
  assert_false(
    comparable(Some(now), previous(Some({ ..earlier, basis: "JST", }))),
  )
  assert_false(
    comparable(Some(now), previous(Some({ ..earlier, week_start: "Sunday", }))),
  )
  assert_false(comparable(Some(now), previous(None)))
  assert_false(comparable(Some(now), None))
  assert_false(comparable(None, previous(Some(earlier))))
}
