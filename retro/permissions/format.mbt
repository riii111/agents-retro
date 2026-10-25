///|
pub fn Report::format(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "# Sandbox report: last \{days} days, \{records} session records\n\n",
  )

  self.prompts.sections(out, "Permission prompts", "by command", limit)
  self.denials.sections(out, "Auto mode denials", "by cause and command", limit)
  self.causes.section(out, "Auto mode denials by cause", limit)

  self.reruns.section(out, "Commands rerun outside the sandbox", limit)
  self.failed.section(out, "Sandboxed commands that failed to write", limit)
  self.writes.section(out, "Paths the sandbox refused to write", limit)
  self.hosts.section(out, "Hosts the sandbox refused", limit)

  out.to_string()
}

///|
fn Events::sections(
  self : Events,
  out : StringBuilder,
  label : String,
  by_command : String,
  limit : Int32,
) -> Unit {
  self.shapes.section(out, "\{label} by command shape", limit)
  self.commands.section(out, "\{label} \{by_command}", limit, format_key=head => {
    "\{head}  (\{self.sessions[head].length()} sessions)"
  })
  self.places.section(out, "\{label} by working directory", limit)
}

///|
fn Counter::section(
  self : Counter,
  out : StringBuilder,
  title : String,
  limit : Int32,
  format_key~ : (String) -> String = key => key,
) -> Unit {
  out.write_string("## \{title}\n")
  if self.counts.is_empty() {
    out.write_string("(none)\n")
  }

  let counts : Array[(String, Int32)] = self.counts.iter().collect()
  let entries = counts.mapi((i, entry) => (entry.0, entry.1, i))
  entries.sort_by((a, b) => {
    if a.1 == b.1 {
      a.2.compare(b.2)
    } else {
      b.1.compare(a.1)
    }
  })

  for i, (key, count, _) in entries {
    if i >= limit {
      break
    }

    let count = count.to_string()
    let padding = if count.length() < 5 {
      " ".repeat(5 - count.length())
    } else {
      ""
    }
    out.write_string("\{padding}\{count}  \{format_key(key)}\n")
  }

  out.write_char('\n')
}
