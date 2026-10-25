///|
struct Counter {
  counts : Map[String, Int32]
}

///|
pub struct Report {
  priv home : String
  priv prompts : Events
  priv denials : Events
  priv causes : Counter
  priv reruns : Counter
  priv failed : Counter
  priv writes : Counter
  priv hosts : Counter
}

///|
struct Events {
  shapes : Counter
  commands : Counter
  places : Counter
  sessions : Map[String, Set[String]]
}

///|
struct Call {
  head : String
  unsandboxed : Bool
}

///|
pub struct Session {
  priv report : Report
  priv calls : Map[String, Call]
}

///|
let write_errors : @string.Regex = regex(
  "Operation not permitted|Read-only file system|attempt to write a readonly database",
)

///|
let quoted_path : @string.Regex = regex(
  "'(/[^'\n]+)'|\"(/[^\"\n]+)\"|(?:on|in|create|open) (/[^\{whitespace_chars}:'\")]+)",
)

///|
let network : @string.Regex = regex(
  "deny network-outbound ([^\{whitespace_chars}:\\\\]+)",
)

///|
pub fn is_candidate_line(line : BytesView) -> Bool {
  line.find(b"\"tool_use\"") is Some(_) ||
  line.find(b"\"tool_result\"") is Some(_) ||
  line.find(b"\\u") is Some(_)
}

///|
pub fn Report::new(home~ : String) -> Report {
  {
    home,
    prompts: Events::new(),
    denials: Events::new(),
    causes: Counter::new(),
    reruns: Counter::new(),
    failed: Counter::new(),
    writes: Counter::new(),
    hosts: Counter::new(),
  }
}

///|
pub fn Report::start_session(self : Report) -> Session {
  { report: self, calls: Map([]), }
}

///|
pub fn Session::read_line(self : Session, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) else { return }
  guard record.get("message") is Some(Object(message)) &&
    message.get("content") is Some(Array(content)) else {
    return
  }

  let report = self.report
  for item in content {
    guard item is Object(item) else { continue }

    if @records.string_field(item, "type") == "tool_use" &&
      @records.string_field(item, "name") == "Bash" {
      guard item.get("id") is Some(String(id)) &&
        item.get("input") is Some(Object(input)) else {
        continue
      }

      let call : Call = {
        head: command_head(@records.string_field(input, "command")),
        unsandboxed: input.get("dangerouslyDisableSandbox") is Some(True),
      }
      self.calls[id] = call
      if call.unsandboxed {
        report.reruns.add(call.head)
      }
    } else if @records.string_field(item, "type") == "tool_result" {
      guard item.get("tool_use_id") is Some(String(id)) &&
        self.calls.get(id) is Some(call) &&
        !call.unsandboxed else {
        continue
      }

      let output = output_text(item.get("content"))
      for m in network.find(output) {
        if m.group(1) is Some(host) {
          report.hosts.add(host.to_owned())
        }
      }

      if write_errors.execute(output) is None {
        continue
      }

      report.failed.add(call.head)
      for line in output.split("\n") {
        if write_errors.execute(line) is None {
          continue
        }

        for m in quoted_path.find(line) {
          for i in 1..<4 {
            if m.group(i) is Some(path) {
              report.writes.add(path_prefix(path.to_owned(), report.home))
              break
            }
          }
        }
      }
    }
  }
}

///|
pub fn Report::read_event(
  self : Report,
  line : StringView,
  since_ms~ : Int64,
) -> Unit {
  guard @records.parse_object(line) is Some(record) else { return }
  guard time_ms(@records.string_field(record, "time")) is Some(stamp) &&
    stamp >= since_ms else {
    return
  }

  let event = @records.string_field(record, "event")
  let counts = match event {
    "PermissionRequest" => self.prompts
    "PermissionDenied" => self.denials
    _ => return
  }

  let cwd = @records.string_field(record, "cwd")
  counts.places.add(
    replace_home(if cwd.is_empty() { "?" } else { cwd }, self.home),
  )

  let (shape, head) = if @records.string_field(record, "tool") == "Bash" {
    let command = @records.string_field(record, "command")
    let shape = command_shape(command)
    (
      if record.get("unsandboxed") is Some(True) {
        shape + " (rerun outside the sandbox)"
      } else {
        shape
      },
      command_head(command),
    )
  } else {
    let tool = @records.string_field(record, "tool")
    let tool = if tool.is_empty() { "unknown" } else { tool }
    ("tool: \{tool}", "tool: \{tool}")
  }

  counts.shapes.add(shape)

  let head = if event == "PermissionDenied" {
    let cause = denial_cause(@records.string_field(record, "reason"))
    self.causes.add(cause)
    "\{cause} | \{head}"
  } else {
    head
  }

  if !counts.sessions.contains(head) {
    counts.sessions[head] = Set([])
  }
  counts.sessions[head].add(@records.string_field(record, "session"))
  counts.commands.add(head)
}

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
fn Events::new() -> Events {
  {
    shapes: Counter::new(),
    commands: Counter::new(),
    places: Counter::new(),
    sessions: Map([]),
  }
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
fn Counter::new() -> Counter {
  { counts: Map([]), }
}

///|
fn Counter::add(self : Counter, key : String) -> Unit {
  self.counts[key] = self.counts.get_or_default(key, 0) + 1
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

///|
fn output_text(content : Json?) -> String {
  match content {
    Some(String(s)) => s
    Some(Array(items)) =>
      items
      .filter_map(item => {
        match item {
          Object(item) => Some(@records.string_field(item, "text"))
          _ => None
        }
      })
      .join("\n")
    _ => ""
  }
}
