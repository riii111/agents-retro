///|
struct PermissionCounter {
  counts : Map[String, Int32]
}

///|
pub struct PermissionReport {
  priv home : String
  priv prompts : PermissionEvents
  priv denials : PermissionEvents
  priv causes : PermissionCounter
  priv reruns : PermissionCounter
  priv failed : PermissionCounter
  priv writes : PermissionCounter
  priv hosts : PermissionCounter
}

///|
struct PermissionEvents {
  shapes : PermissionCounter
  commands : PermissionCounter
  places : PermissionCounter
  sessions : Map[String, Set[String]]
}

///|
struct PermissionCall {
  head : String
  unsandboxed : Bool
}

///|
pub struct PermissionSession {
  priv report : PermissionReport
  priv calls : Map[String, PermissionCall]
}

///|
let permission_write_errors : @string.Regex = permission_regex(
  "Operation not permitted|Read-only file system|attempt to write a readonly database",
)

///|
let permission_quoted_path : @string.Regex = permission_regex(
  "'(/[^'\n]+)'|\"(/[^\"\n]+)\"|(?:on|in|create|open) (/[^\{permission_whitespace}:'\")]+)",
)

///|
let permission_network : @string.Regex = permission_regex(
  "deny network-outbound ([^\{permission_whitespace}:\\\\]+)",
)

///|
pub fn PermissionReport::new(home~ : String) -> PermissionReport {
  {
    home,
    prompts: PermissionEvents::new(),
    denials: PermissionEvents::new(),
    causes: PermissionCounter::new(),
    reruns: PermissionCounter::new(),
    failed: PermissionCounter::new(),
    writes: PermissionCounter::new(),
    hosts: PermissionCounter::new(),
  }
}

///|
pub fn PermissionReport::start_session(
  self : PermissionReport,
) -> PermissionSession {
  { report: self, calls: Map([]), }
}

///|
pub fn PermissionSession::read_line(
  self : PermissionSession,
  line : StringView,
) -> Unit {
  guard parse_object(line) is Some(record) else { return }
  guard record.get("message") is Some(Object(message)) &&
    message.get("content") is Some(Array(content)) else {
    return
  }
  let report = self.report
  for item in content {
    guard item is Object(item) else { continue }
    if string_field(item, "type") == "tool_use" &&
      string_field(item, "name") == "Bash" {
      guard item.get("id") is Some(String(id)) &&
        item.get("input") is Some(Object(input)) else {
        continue
      }
      let call : PermissionCall = {
        head: permission_command_head(string_field(input, "command")),
        unsandboxed: input.get("dangerouslyDisableSandbox") is Some(True),
      }
      self.calls[id] = call
      if call.unsandboxed {
        report.reruns.add(call.head)
      }
    } else if string_field(item, "type") == "tool_result" {
      guard item.get("tool_use_id") is Some(String(id)) &&
        self.calls.get(id) is Some(call) &&
        !call.unsandboxed else {
        continue
      }
      let output = permission_output(item.get("content"))
      for m in permission_network.find(output) {
        if m.group(1) is Some(host) {
          report.hosts.add(host.to_owned())
        }
      }
      if permission_write_errors.execute(output) is None {
        continue
      }
      report.failed.add(call.head)
      for line in output.split("\n") {
        if permission_write_errors.execute(line) is None {
          continue
        }
        for m in permission_quoted_path.find(line) {
          for i in 1..<4 {
            if m.group(i) is Some(path) {
              report.writes.add(
                permission_path_prefix(path.to_owned(), report.home),
              )
              break
            }
          }
        }
      }
    }
  }
}

///|
pub fn PermissionReport::read_event(
  self : PermissionReport,
  line : StringView,
  since_ms~ : Int64,
) -> Unit {
  guard parse_object(line) is Some(record) else { return }
  guard permission_time_ms(string_field(record, "time")) is Some(stamp) &&
    stamp >= since_ms else {
    return
  }
  let event = string_field(record, "event")
  let counts = match event {
    "PermissionRequest" => self.prompts
    "PermissionDenied" => self.denials
    _ => return
  }
  let cwd = string_field(record, "cwd")
  counts.places.add(
    permission_replace_home(if cwd.is_empty() { "?" } else { cwd }, self.home),
  )
  let (shape, head) = if string_field(record, "tool") == "Bash" {
    let command = string_field(record, "command")
    let shape = permission_command_shape(command)
    (
      if record.get("unsandboxed") is Some(True) {
        shape + " (rerun outside the sandbox)"
      } else {
        shape
      },
      permission_command_head(command),
    )
  } else {
    let tool = string_field(record, "tool")
    let tool = if tool.is_empty() { "unknown" } else { tool }
    ("tool: \{tool}", "tool: \{tool}")
  }
  counts.shapes.add(shape)
  let head = if event == "PermissionDenied" {
    let cause = permission_denial_cause(string_field(record, "reason"))
    self.causes.add(cause)
    "\{cause} | \{head}"
  } else {
    head
  }
  if !counts.sessions.contains(head) {
    counts.sessions[head] = Set([])
  }
  counts.sessions[head].add(string_field(record, "session"))
  counts.commands.add(head)
}

///|
pub fn PermissionReport::format(
  self : PermissionReport,
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
fn PermissionEvents::new() -> PermissionEvents {
  {
    shapes: PermissionCounter::new(),
    commands: PermissionCounter::new(),
    places: PermissionCounter::new(),
    sessions: Map([]),
  }
}

///|
fn PermissionEvents::sections(
  self : PermissionEvents,
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
fn PermissionCounter::new() -> PermissionCounter {
  { counts: Map([]), }
}

///|
fn PermissionCounter::add(self : PermissionCounter, key : String) -> Unit {
  self.counts[key] = self.counts.get_or_default(key, 0) + 1
}

///|
fn PermissionCounter::section(
  self : PermissionCounter,
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
fn permission_output(content : Json?) -> String {
  match content {
    Some(String(s)) => s
    Some(Array(items)) =>
      items
      .filter_map(item => {
        match item {
          Object(item) => Some(string_field(item, "text"))
          _ => None
        }
      })
      .join("\n")
    _ => ""
  }
}
