///|
pub struct ClaudeLog {
  priv report : Report
  priv calls : Map[String, Tool]
  priv mut previous : Tool
}

///|
let no_tool : Tool = { name: "(no tool call)", command: "", }

///|
let rejection_prefix = "The user doesn't want to"

///|
pub fn is_claude_candidate(line : BytesView) -> Bool {
  line.find(b"\"tool_use\"") is Some(_) ||
  line.find(b"\"role\":\"user\"") is Some(_)
}

///|
pub fn Report::claude_log(self : Report) -> ClaudeLog {
  { report: self, calls: Map([]), previous: no_tool, }
}

///|
/// `previous` is the last tool call since the latest user prompt, which is the call an interruption cut short.
pub fn ClaudeLog::read_line(self : ClaudeLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) &&
    record.get("message") is Some(Object(message)) else {
    return
  }

  match @records.string_field(record, "type") {
    "assistant" => self.read_assistant(message)
    "user" => self.read_user(record, message)
    _ => ()
  }
}

///|
fn ClaudeLog::read_assistant(
  self : ClaudeLog,
  message : Map[String, Json],
) -> Unit {
  guard message.get("content") is Some(Array(content)) else { return }

  for item in content {
    guard item is Object(item) &&
      @records.string_field(item, "type") == "tool_use" &&
      item.get("id") is Some(String(id)) else {
      continue
    }

    let name = @records.string_field(item, "name")
    let command = if name == "Bash" && item.get("input") is Some(Object(input)) {
      @shell.command_head(@records.string_field(input, "command"))
    } else {
      ""
    }
    let tool = { name, command, }
    self.calls[id] = tool
    self.previous = tool
  }
}

///|
fn ClaudeLog::read_user(
  self : ClaudeLog,
  record : Map[String, Json],
  message : Map[String, Json],
) -> Unit {
  match message.get("content") {
    Some(String(_)) => self.previous = no_tool
    Some(Array(content)) =>
      for item in content {
        guard item is Object(item) else { continue }

        match @records.string_field(item, "type") {
          "tool_result" => self.read_result(record, item)
          "text" => self.read_text(record, @records.string_field(item, "text"))
          _ => self.previous = no_tool
        }
      }
    _ => ()
  }
}

///|
fn ClaudeLog::read_text(
  self : ClaudeLog,
  record : Map[String, Json],
  text : String,
) -> Unit {
  let event = match text.trim().to_owned() {
    "[Request interrupted by user]" => Some(Interrupt)
    "[Request interrupted by user for tool use]" => Some(ToolUseInterrupt)
    _ => None
  }
  if event is Some(event) {
    self.add(record, event, self.previous)
  }
  self.previous = no_tool
}

///|
fn ClaudeLog::read_result(
  self : ClaudeLog,
  record : Map[String, Json],
  item : Map[String, Json],
) -> Unit {
  guard item.get("is_error") is Some(True) &&
    @records.content_text(item.get("content")).has_prefix(rejection_prefix) else {
    return
  }

  let tool = match item.get("tool_use_id") {
    Some(String(id)) =>
      self.calls.get(id).unwrap_or({ name: "(unknown)", command: "", })
    _ => { name: "(unknown)", command: "", }
  }
  self.add(record, Rejection, tool)
}

///|
fn ClaudeLog::add(
  self : ClaudeLog,
  record : Map[String, Json],
  event : Event,
  tool : Tool,
) -> Unit {
  let session = @records.string_field(record, "sessionId")
  let project = @records.string_field(record, "cwd")
  self.report.add_event(
    @records.string_field(record, "uuid"),
    event,
    session=if session.is_empty() { "(unknown)" } else { session },
    project=if project.is_empty() { "(unknown)" } else { project },
    sidechain=record.get("isSidechain") is Some(True),
    tool,
  )
}
