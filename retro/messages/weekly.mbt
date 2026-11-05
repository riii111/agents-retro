///|
/// The clock and week boundary a run measured with, saved so a later run compares only with a run measured the same way.
pub(all) struct Period {
  days : Int64
  until : String
  basis : String
  week_start : String
}

///|
pub fn Period::utc(days~ : Int64, until_ms~ : Int64) -> Period {
  { days, until: utc_isoformat(until_ms), basis: "UTC", week_start: "Monday", }
}

///|
fn Period::aligned_with(self : Period, other : Period) -> Bool {
  self.days == other.days &&
  self.basis == other.basis &&
  self.week_start == other.week_start
}

///|
/// Whether the previous run can be compared with this one. A run without a period is of unknown length.
fn comparable(period : Period?, previous : PreviousMetrics?) -> Bool {
  match (period, previous.bind(p => p.period)) {
    (Some(now), Some(before)) => now.aligned_with(before)
    _ => false
  }
}

///|
pub(all) struct AppCount {
  app : String
  messages : Int32
  sessions : Int32
  patterns : Array[PatternCount]
}

///|
pub(all) struct Week {
  start : String
  end : String
  partial : Bool
  covers_from : String
  covers_until : String
  sessions : Int32
  apps : Array[AppCount]
}

///|
let ms_per_day : Int64 = 86_400_000L

///|
/// Splits the period into UTC weeks from Monday 00:00, including weeks without messages so a gap is not mistaken for a missing week.
/// The first and last week are partial when the period cuts them.
/// Each app lists only the patterns it matched.
pub fn weekly_breakdown(
  messages : Array[Message],
  hits : Array[PatternHits],
  since_ms~ : Int64,
  until_ms~ : Int64,
) -> Array[Week] {
  let week_of : Map[Int32, Int64] = Map([])
  for m in messages {
    if @clock.days_from_date(m.ts) is Some(days) {
      week_of[m.id] = @clock.week_start_days(days)
    }
  }

  let matched = hits.map(h => Set::from_iter(h.messages.iter().map(m => m.id)))
  let weeks = []
  let last = week_start_of(until_ms)
  let mut day = week_start_of(since_ms)
  while day <= last {
    let from_ms = day * ms_per_day
    let to_ms = (day + 7L) * ms_per_day
    let in_week = messages.filter(m => week_of.get(m.id) == Some(day))
    let covers_from = if since_ms > from_ms { since_ms } else { from_ms }
    let covers_until = if until_ms < to_ms { until_ms } else { to_ms }

    weeks.push({
      start: @clock.date_from_days(day),
      end: @clock.date_from_days(day + 6L),
      partial: since_ms > from_ms || until_ms < to_ms,
      covers_from: "\{@clock.utc_timestamp(covers_from)}Z",
      covers_until: "\{@clock.utc_timestamp(covers_until)}Z",
      sessions: session_count(in_week),
      apps: app_counts(in_week, hits, matched),
    })
    day += 7L
  }

  weeks
}

///|
/// The same per-app counts over the whole period, so sessions are counted once across weeks.
pub fn app_breakdown(
  messages : Array[Message],
  hits : Array[PatternHits],
) -> Array[AppCount] {
  let matched = hits.map(h => Set::from_iter(h.messages.iter().map(m => m.id)))
  app_counts(messages, hits, matched)
}

///|
fn week_start_of(ms : Int64) -> Int64 {
  @clock.week_start_days(
    @clock.days_from_date(@clock.utc_date(ms)).unwrap_or(0L),
  )
}

///|
fn app_counts(
  in_week : Array[Message],
  hits : Array[PatternHits],
  matched : Array[Set[Int32]],
) -> Array[AppCount] {
  let apps = Set::from_iter(in_week.iter().map(m => m.app)).iter().collect()
  apps.sort_by((a, b) => a.lexical_compare(b))
  apps.map(app => {
    let own = in_week.filter(m => m.app == app)
    let patterns = []
    for i, h in hits {
      let found = own.filter(m => matched[i].contains(m.id))
      if !found.is_empty() {
        patterns.push({
          name: h.name,
          messages: found.length(),
          sessions: session_count(found),
        })
      }
    }

    { app, messages: own.length(), sessions: session_count(own), patterns, }
  })
}

///|
fn apps_json(apps : Array[AppCount], depth~ : Int32) -> String {
  let entries = apps.map(a => {
    let patterns = a.patterns.map(c => {
      let counts = [
        ("messages", c.messages.to_string()),
        ("sessions", c.sessions.to_string()),
      ]
      (c.name, json_object(counts, depth=depth + 3))
    })
    let fields = [
      ("messages", a.messages.to_string()),
      ("sessions", a.sessions.to_string()),
      ("patterns", json_object(patterns, depth=depth + 2)),
    ]
    (a.app, json_object(fields, depth=depth + 1))
  })

  json_object(entries, depth~)
}

///|
fn weeks_json(weeks : Array[Week]) -> String {
  let entries = weeks.map(w => {
    let fields = [
      ("end", json_string(w.end)),
      ("partial", w.partial.to_string()),
      ("covers_from", json_string(w.covers_from)),
      ("covers_until", json_string(w.covers_until)),
      ("sessions", w.sessions.to_string()),
      ("apps", apps_json(w.apps, depth=3)),
    ]
    (w.start, json_object(fields, depth=2))
  })

  json_object(entries, depth=1)
}
