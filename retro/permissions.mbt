///|
struct PermissionCounter {
  counts : Map[String, Int32]
  order : Array[String]
}

///|
pub struct PermissionReport {
  priv home : String
  priv shapes : Array[PermissionCounter]
  priv commands : Array[PermissionCounter]
  priv places : Array[PermissionCounter]
  priv sessions : Array[Map[String, Set[String]]]
  priv causes : PermissionCounter
  priv reruns : PermissionCounter
  priv failed : PermissionCounter
  priv writes : PermissionCounter
  priv hosts : PermissionCounter
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
let permission_lines : @string.Regex = permission_regex(
  "\r\n|[\n\r\u{0b}\u{0c}\u{1c}-\u{1e}\u{85}\u{2028}\u{2029}]",
)

///|
pub fn PermissionReport::new(home~ : String) -> PermissionReport {
  {
    home,
    shapes: [PermissionCounter::new(), PermissionCounter::new()],
    commands: [PermissionCounter::new(), PermissionCounter::new()],
    places: [PermissionCounter::new(), PermissionCounter::new()],
    sessions: [Map([]), Map([])],
    causes: PermissionCounter::new(),
    reruns: PermissionCounter::new(),
    failed: PermissionCounter::new(),
    writes: PermissionCounter::new(),
    hosts: PermissionCounter::new(),
  }
}

///|
/// Call once per file so tool IDs from different sessions cannot collide.
pub fn PermissionReport::scan_session(
  self : PermissionReport,
  source : String,
) -> Unit {
  let calls : Map[String, Map[String, Json]] = Map([])
  for line in permission_lines.split(source) {
    guard parse_object(line) is Some(record) else { continue }
    guard record.get("message") is Some(Object(message)) &&
      message.get("content") is Some(Array(content)) else {
      continue
    }
    for item in content {
      guard item is Object(item) else { continue }
      if string_field(item, "type") == "tool_use" &&
        string_field(item, "name") == "Bash" {
        let input = match item.get("input") {
          Some(Object(input)) => input
          _ => Map([])
        }
        calls[permission_json_key(item.get("id"))] = input
        if permission_truthy(input.get("dangerouslyDisableSandbox")) {
          self.reruns.add(
            permission_command_head(string_field(input, "command")),
          )
        }
      } else if string_field(item, "type") == "tool_result" {
        guard calls.get(permission_json_key(item.get("tool_use_id")))
          is Some(call) &&
          !permission_truthy(call.get("dangerouslyDisableSandbox")) else {
          continue
        }
        let output = permission_output(item.get("content"))
        for m in permission_network.find(output) {
          if m.group(1) is Some(host) {
            self.hosts.add(host.to_owned())
          }
        }
        if permission_write_errors.execute(output) is None {
          continue
        }
        self.failed.add(permission_command_head(string_field(call, "command")))
        for line in permission_lines.split(output) {
          if permission_write_errors.execute(line) is None {
            continue
          }
          for m in permission_quoted_path.find(line) {
            for i in 1..<4 {
              if m.group(i) is Some(path) {
                self.writes.add(
                  permission_path_prefix(path.to_owned(), self.home),
                )
                break
              }
            }
          }
        }
      }
    }
  }
}

///|
pub fn PermissionReport::scan_events(
  self : PermissionReport,
  source : String,
  since_ms~ : Int64,
) -> Unit {
  for line in permission_lines.split(source) {
    guard parse_object(line) is Some(record) else { continue }
    guard permission_time_us(string_field(record, "time")) is Some(stamp) &&
      stamp >= since_ms * 1000L else {
      continue
    }
    let event = match string_field(record, "event") {
      "PermissionRequest" => 0
      "PermissionDenied" => 1
      _ => continue
    }
    let cwd = string_field(record, "cwd")
    self.places[event].add(
      permission_replace_home(if cwd.is_empty() { "?" } else { cwd }, self.home),
    )
    let (shape, head) = if string_field(record, "tool") == "Bash" {
      let command = string_field(record, "command")
      let shape = permission_command_shape(command)
      (
        if permission_truthy(record.get("unsandboxed")) {
          shape + " (rerun outside the sandbox)"
        } else {
          shape
        },
        permission_command_head(command),
      )
    } else {
      let tool = match record.get("tool") {
        Some(String(tool)) => tool
        _ => "None"
      }
      ("tool: \{tool}", "tool: \{tool}")
    }
    self.shapes[event].add(shape)
    let head = if event == 1 {
      let cause = permission_denial_cause(string_field(record, "reason"))
      self.causes.add(cause)
      "\{cause} | \{head}"
    } else {
      head
    }
    if !self.sessions[event].contains(head) {
      self.sessions[event][head] = Set([])
    }
    self.sessions[event][head].add(permission_json_key(record.get("session")))
    self.commands[event].add(head)
  }
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
  for event, label in ["Permission prompts", "Auto mode denials"] {
    self.shapes[event].section(out, "\{label} by command shape", limit)
    let commands = PermissionCounter::new()
    for head in self.commands[event].order {
      let sessions = self.sessions[event][head].length()
      let key = "\{head}  (\{sessions} sessions)"
      commands.order.push(key)
      commands.counts[key] = self.commands[event].counts[head]
    }
    commands.section(
      out,
      "\{label} \{if event == 0 { "by command" } else { "by cause and command" }}",
      limit,
    )
    self.places[event].section(out, "\{label} by working directory", limit)
  }
  self.causes.section(out, "Auto mode denials by cause", limit)
  self.reruns.section(out, "Commands rerun outside the sandbox", limit)
  self.failed.section(out, "Sandboxed commands that failed to write", limit)
  self.writes.section(out, "Paths the sandbox refused to write", limit)
  self.hosts.section(out, "Hosts the sandbox refused", limit)
  out.to_string()
}

///|
fn PermissionCounter::new() -> PermissionCounter {
  { counts: Map([]), order: [], }
}

///|
fn PermissionCounter::add(self : PermissionCounter, key : String) -> Unit {
  if !self.counts.contains(key) {
    self.order.push(key)
  }
  self.counts[key] = self.counts.get_or_default(key, 0) + 1
}

///|
/// Counter.most_common preserves first occurrence for ties, even with a limit.
fn PermissionCounter::section(
  self : PermissionCounter,
  out : StringBuilder,
  title : String,
  limit : Int32,
) -> Unit {
  out.write_string("## \{title}\n")
  if self.order.is_empty() {
    out.write_string("(none)\n")
  }
  let entries = self.order.mapi((i, key) => (key, self.counts[key], i))
  entries.sort_by((a, b) => {
    if a.1 == b.1 {
      a.2.compare(b.2)
    } else {
      b.1.compare(a.1)
    }
  })
  for i, entry in entries {
    if i >= limit {
      break
    }
    let count = entry.1.to_string()
    let padding = if count.length() < 5 {
      " ".repeat(5 - count.length())
    } else {
      ""
    }
    out.write_string("\{padding}\{count}  \{entry.0}\n")
  }
  out.write_char('\n')
}

///|
fn permission_json_key(value : Json?) -> String {
  match value {
    Some(value) => value.stringify()
    None => "null"
  }
}

///|
fn permission_truthy(value : Json?) -> Bool {
  match value {
    None | Some(Null) | Some(False) => false
    Some(Number(n, ..)) => n != 0.0
    Some(String(s)) => !s.is_empty()
    Some(Array(a)) => !a.is_empty()
    Some(Object(o)) => !o.is_empty()
    _ => true
  }
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
