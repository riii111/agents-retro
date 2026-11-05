///|
pub(all) struct Metrics {
  since : String
  messages : Int32
  sessions : Int32
  delegated : Int32
  by_role : Array[(String, Int32)]
  unmatched : Int32
  patterns : Array[PatternCount]
  /// Set only by the options that add period-aware output; plain runs keep the original layout.
  period : Period?
  /// Whether the period-aware sections are printed; the period itself is always recorded for comparisons.
  detailed : Bool
  apps : Array[AppCount]
  weeks : Array[Week]
  candidates : Array[CandidateCount]
}

///|
struct PreviousMetrics {
  date : String
  patterns : Map[String, PatternCount]
  period : Period?
  candidates : Map[String, CandidateCount]
}

///|
/// Uses the layout of Python's `json.dump(ensure_ascii=False, indent=1)` so the files of both versions compare line by line.
pub fn Metrics::to_json(self : Metrics) -> String {
  let patterns = self.patterns.map(c => {
    let counts = [
      ("messages", c.messages.to_string()),
      ("sessions", c.sessions.to_string()),
    ]
    (c.name, json_object(counts, depth=2))
  })

  let fields = [
    ("since", json_string(self.since)),
    ("messages", self.messages.to_string()),
    ("sessions", self.sessions.to_string()),
    ("delegated", self.delegated.to_string()),
    (
      "by_role",
      json_object(self.by_role.map(e => (e.0, e.1.to_string())), depth=1),
    ),
    ("unmatched", self.unmatched.to_string()),
    ("patterns", json_object(patterns, depth=1)),
  ]
  if self.period is Some(p) {
    let basis = [
      ("basis", json_string(p.basis)),
      ("week_start", json_string(p.week_start)),
      ("days", p.days.to_string()),
      ("until", json_string(p.until)),
    ]
    fields.push(("period", json_object(basis, depth=1)))
    if !self.candidates.is_empty() {
      let entries = self.candidates.map(c => {
        let counts = [
          ("messages", c.messages.to_string()),
          ("sessions", c.sessions.to_string()),
          ("outside_patterns", c.outside_patterns.to_string()),
          ("first_seen", json_string(c.first_seen)),
        ]
        (c.name, json_object(counts, depth=2))
      })
      fields.push(("candidates", json_object(entries, depth=1)))
    }
    if !self.apps.is_empty() {
      fields.push(("apps", apps_json(self.apps, depth=1)))
    }
    if !self.weeks.is_empty() {
      fields.push(("weeks", weeks_json(self.weeks)))
    }
  }

  json_object(fields, depth=0)
}

///|
/// Returns `None` for an empty object, which Python treats as no previous run.
pub fn parse_previous_metrics(
  source : String,
  date~ : String,
) -> PreviousMetrics? raise {
  guard @json.parse(source) is Object(obj) else {
    fail("previous metrics must be a JSON object")
  }
  if obj.is_empty() {
    return None
  }

  let patterns : Map[String, PatternCount] = Map([])
  match obj.get("patterns") {
    None => ()
    Some(Object(entries)) =>
      for name, entry in entries {
        guard entry is Object(counts) else {
          fail("previous metrics for \{name} must be an object")
        }
        if counts.is_empty() {
          continue
        }

        guard counts.get("messages") is Some(Number(messages, ..)) &&
          counts.get("sessions") is Some(Number(sessions, ..)) else {
          fail("previous metrics for \{name} lack message or session counts")
        }

        patterns[name] = {
          name,
          messages: messages.to_int(),
          sessions: sessions.to_int(),
        }
      }
    Some(_) => fail("previous metrics patterns must be an object")
  }

  Some({
    date,
    patterns,
    period: previous_period(obj.get("period")),
    candidates: previous_candidates(obj.get("candidates"), date~),
  })
}

///|
/// Anything unreadable is treated as unknown, which is never compared.
fn previous_period(source : Json?) -> Period? {
  guard source is Some(Object(p)) else { return None }
  guard p.get("basis") is Some(String(basis)) &&
    p.get("week_start") is Some(String(week_start)) &&
    p.get("days") is Some(Number(days, ..)) else {
    return None
  }

  let until = match p.get("until") {
    Some(String(until)) => until
    _ => ""
  }

  Some({ days: days.to_int64(), until, basis, week_start, })
}

///|
fn previous_candidates(
  source : Json?,
  date~ : String,
) -> Map[String, CandidateCount] {
  let candidates : Map[String, CandidateCount] = Map([])
  guard source is Some(Object(entries)) else { return candidates }

  for name, entry in entries {
    guard entry is Object(counts) &&
      counts.get("messages") is Some(Number(messages, ..)) &&
      counts.get("sessions") is Some(Number(sessions, ..)) else {
      continue
    }

    let outside = match counts.get("outside_patterns") {
      Some(Number(n, ..)) => n.to_int()
      _ => 0
    }
    let first_seen = match counts.get("first_seen") {
      Some(String(d)) => d
      _ => date
    }
    candidates[name] = {
      name,
      messages: messages.to_int(),
      sessions: sessions.to_int(),
      outside_patterns: outside,
      first_seen,
      seen_before: true,
    }
  }

  candidates
}

///|
fn json_object(fields : Array[(String, String)], depth~ : Int32) -> String {
  if fields.is_empty() {
    return "{}"
  }

  let indent = " ".repeat(depth + 1)
  let body = fields.map(f => "\{indent}\{json_string(f.0)}: \{f.1}").join(",\n")
  "{\n\{body}\n\{" ".repeat(depth)}}"
}

///|
/// Escapes the same characters as Python's `json` with `ensure_ascii=False`.
fn json_string(s : String) -> String {
  let out = StringBuilder()

  out.write_char('"')
  for c in s {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      '\u{08}' => out.write_string("\\b")
      '\u{0c}' => out.write_string("\\f")
      _ if c.to_int() < 0x20 => {
        let hex = "0123456789abcdef"
        out.write_string("\\u00")
        out.write_char(hex.get_char(c.to_int() / 16).unwrap())
        out.write_char(hex.get_char(c.to_int() % 16).unwrap())
      }
      _ => out.write_char(c)
    }
  }

  out.write_char('"')

  out.to_string()
}
