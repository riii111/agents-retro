///|
fn sample_metrics() -> Metrics {
  {
    since: "2026-10-17T01:02:03.456000+00:00",
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
  let empty : Metrics = { ..sample_metrics(), by_role: [], patterns: [], }

  assert_true(empty.to_json().contains(" \"by_role\": {},\n"))
  assert_true(empty.to_json().has_suffix(" \"patterns\": {}\n}"))
}

///|
test "parse_previous_metrics reads its own output" {
  let previous = parse_previous_metrics(
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
  assert_true(parse_previous_metrics("{}", date="d") is None)

  guard parse_previous_metrics("{\"messages\": 1}", date="d") is Some(p) else {
    fail("expected previous metrics")
  }
  assert_true(p.patterns.is_empty())
}

///|
fn period_metrics() -> Metrics {
  {
    ..sample_metrics(),
    period: Some(Period::utc(days=7L, until_ms=1_792_551_600_000L)),
    apps: [
      {
        app: "claude",
        messages: 4,
        sessions: 2,
        patterns: [{ name: "review", messages: 3, sessions: 2, }],
      },
    ],
    weeks: [
      {
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
      },
    ],
    candidates: [
      {
        name: "fix",
        messages: 3,
        sessions: 2,
        outside_patterns: 1,
        first_seen: "2026-10-13",
        seen_before: true,
      },
    ],
  }
}

///|
test "to_json adds the period, candidates and weeks only when they are set" {
  let json = period_metrics().to_json()

  let expected =
    #| "patterns": {
    #|  "review": {
    #|   "messages": 2,
    #|   "sessions": 1
    #|  },
    #|  "引用\"と\\と\t": {
    #|   "messages": 0,
    #|   "sessions": 0
    #|  }
    #| },
    #| "period": {
    #|  "basis": "UTC",
    #|  "week_start": "Monday",
    #|  "days": 7,
    #|  "until": "2026-10-21T03:00:00+00:00"
    #| },
    #| "candidates": {
    #|  "fix": {
    #|   "messages": 3,
    #|   "sessions": 2,
    #|   "outside_patterns": 1,
    #|   "first_seen": "2026-10-13"
    #|  }
    #| },
    #| "apps": {
    #|  "claude": {
    #|   "messages": 4,
    #|   "sessions": 2,
    #|   "patterns": {
    #|    "review": {
    #|     "messages": 3,
    #|     "sessions": 2
    #|    }
    #|   }
    #|  }
    #| },
    #| "weeks": {
    #|  "2026-10-19": {
    #|   "end": "2026-10-25",
    #|   "partial": true,
    #|   "covers_from": "2026-10-19T00:00:00Z",
    #|   "covers_until": "2026-10-21T03:00:00Z",
    #|   "sessions": 1,
    #|   "apps": {
    #|    "claude": {
    #|     "messages": 2,
    #|     "sessions": 1,
    #|     "patterns": {
    #|      "review": {
    #|       "messages": 2,
    #|       "sessions": 1
    #|      }
    #|     }
    #|    }
    #|   }
    #|  }
    #| }
    #|}

  assert_true(json.contains(expected.trim_end(chars="\n").to_owned()))
  assert_false(sample_metrics().to_json().contains("period"))
}

///|
test "parse_previous_metrics reads the period and candidates it wrote" {
  guard parse_previous_metrics(period_metrics().to_json(), date="2026-10-21")
    is Some(p) else {
    fail("expected previous metrics")
  }

  assert_eq(
    p.period.map(q => (q.days, q.basis, q.week_start)),
    Some((7L, "UTC", "Monday")),
  )
  assert_eq(
    p.candidates.get("fix").map(c => (c.messages, c.first_seen)),
    Some((3, "2026-10-13")),
  )
}

///|
test "parse_previous_metrics treats a missing or broken period as unknown" {
  for
    source in [
      "{\"messages\": 1}", "{\"period\": 3}", "{\"period\": {\"basis\": \"UTC\"}}",
      "{\"period\": {\"basis\": 1, \"week_start\": \"Monday\", \"days\": 7}}",
    ] {
    guard parse_previous_metrics(source, date="d") is Some(p) else {
      fail("expected previous metrics")
    }

    assert_true(p.period is None)
  }

  // A previous candidate without a first sighting date counts from that run.
  guard parse_previous_metrics(
      "{\"candidates\": {\"x\": {\"messages\": 1, \"sessions\": 1}, \"bad\": 1}}",
      date="2026-10-13",
    )
    is Some(p) else {
    fail("expected previous metrics")
  }

  assert_eq(p.candidates.get("x").map(c => c.first_seen), Some("2026-10-13"))
  assert_true(p.candidates.get("bad") is None)
}
