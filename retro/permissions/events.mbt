///|
let rule : @string.Regex = regex("\\[([^\\]]+)\\]")

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
fn denial_cause(reason : String) -> String {
  if reason.is_empty() {
    "unknown"
  } else if reason.has_prefix("Classifier unavailable") {
    "classifier unavailable (not a settings issue)"
  } else if reason.has_prefix("Auto mode could not evaluate") {
    "no verdict (not a settings issue)"
  } else if rule.execute(reason) is Some(m) && m.group(1) is Some(rule) {
    "rule: \{rule}"
  } else {
    "other"
  }
}

///|
fn replace_home(path : String, home : String) -> String {
  if path == home {
    "~"
  } else if path.strip_prefix(home + "/") is Some(rest) {
    "~/\{rest}"
  } else {
    path
  }
}
