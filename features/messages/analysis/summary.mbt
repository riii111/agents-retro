///|
/// Same lines and order as the Python version's standard output.
pub fn format_summary(
  metrics : Metrics,
  previous : PreviousMetrics?,
  examples_path~ : String,
  unmatched_paths~ : Array[String],
  messages_path~ : String,
) -> String {
  let lines = [
    "Owner messages: \{metrics.messages} in \{metrics.sessions} sessions (agent-to-agent messages excluded: \{metrics.delegated})",
  ]
  for entry in metrics.by_role {
    lines.push("  \{entry.0}: \{entry.1}")
  }

  // A run with a period compares only with a run measured the same way.
  let (previous, note) = match (metrics.period, previous) {
    (Some(_), Some(p)) if !comparable(metrics.period, previous) =>
      (
        None,
        "  vs \{p.date}: not compared (that run covered a different or unknown period)",
      )
    (_, Some(p)) => (previous, "  vs \{p.date}")
    _ => (None, "")
  }
  if metrics.detailed && metrics.period is Some(p) {
    lines.push(
      "Period: last \{p.days} days until \{p.until} (\{p.basis}; weeks start \{p.week_start} 00:00)",
    )
  }

  let total = if metrics.detailed {
    ", \{metrics.sessions} sessions in period"
  } else {
    ""
  }
  lines.push("\nPatterns (messages / sessions\{total})\{note}")
  for c in metrics.patterns {
    let delta = match previous.bind(p => p.patterns.get(c.name)) {
      Some(before) => "  (was \{before.messages} / \{before.sessions})"
      None => ""
    }
    lines.push("  \{c.name}: \{c.messages} / \{c.sessions}\{delta}")
  }

  if !metrics.candidates.is_empty() {
    lines.push("\nCandidates (messages / sessions; not part of the patterns)")
    for c in metrics.candidates {
      lines.push(candidate_line(c, previous))
    }
  }

  lines.push("\nUnmatched by any pattern: \{metrics.unmatched}")
  if !metrics.apps.is_empty() {
    lines.push("\nBy app, whole period (messages / sessions per pattern)")
    lines.push_iter(app_lines(metrics.apps).iter())
  }
  if !metrics.weeks.is_empty() {
    lines.push("")
    lines.push_iter(weekly_lines(metrics.weeks).iter())
  }

  lines.push("\nExamples: \{examples_path}")
  for path in unmatched_paths {
    lines.push("Unmatched: \{path}")
  }
  lines.push("Messages (full text, line number = id): \{messages_path}")

  lines.join("\n")
}

///|
/// `previous` is `None` when that run cannot be compared, so no earlier counts are shown then.
fn candidate_line(c : CandidateCount, previous : PreviousMetrics?) -> String {
  let status = if !c.seen_before {
    "new"
  } else {
    let since = "tracked since \{c.first_seen}"
    match previous.bind(p => p.candidates.get(c.name)) {
      Some(before) => "\{since}, was \{before.messages} / \{before.sessions}"
      None => since
    }
  }

  "  \{c.name}: \{c.messages} / \{c.sessions}  (\{status}; \{c.outside_patterns} messages outside the patterns)"
}

///|
fn app_lines(apps : Array[AppCount]) -> Array[String] {
  let lines = []
  for a in apps {
    lines.push("  \{a.app}: \{a.messages} messages in \{a.sessions} sessions")
    for c in a.patterns {
      lines.push("    \{c.name}: \{c.messages} / \{c.sessions}")
    }
  }

  lines
}

///|
fn weekly_lines(weeks : Array[Week]) -> Array[String] {
  let lines = ["Weekly by app (messages / sessions per pattern)"]
  for w in weeks {
    let cut = if w.partial {
      " (partial week: covers \{w.covers_from} until \{w.covers_until})"
    } else {
      ""
    }
    lines.push("\{w.start} to \{w.end}: \{w.sessions} sessions\{cut}")
    lines.push_iter(app_lines(w.apps).iter())
  }

  lines
}
