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

  let versus = match previous {
    Some(p) => "  vs \{p.date}"
    None => ""
  }
  lines.push("\nPatterns (messages / sessions)\{versus}")
  for c in metrics.patterns {
    let delta = match previous.bind(p => p.patterns.get(c.name)) {
      Some(before) => "  (was \{before.messages} / \{before.sessions})"
      None => ""
    }
    lines.push("  \{c.name}: \{c.messages} / \{c.sessions}\{delta}")
  }

  lines.push("\nUnmatched by any pattern: \{metrics.unmatched}")

  lines.push("\nExamples: \{examples_path}")
  for path in unmatched_paths {
    lines.push("Unmatched: \{path}")
  }
  lines.push("Messages (full text, line number = id): \{messages_path}")

  lines.join("\n")
}
