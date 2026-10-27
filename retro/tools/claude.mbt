///|
pub struct ClaudeLog {
  priv report : Report
  priv fallback_session : String
  priv calls : Map[String, Call]
}

///|
const UNKNOWN_TOOL : String = "(unknown)"

///|
pub fn is_claude_candidate(line : BytesView) -> Bool {
  line.find(b"\"tool_use\"") is Some(_) ||
  line.find(b"\"is_error\":true") is Some(_)
}

///|
/// A log is one file: a conversation or one subagent.
pub fn Report::claude_log(self : Report, session~ : String) -> ClaudeLog {
  { report: self, fallback_session: session, calls: Map([]), }
}

///|
pub fn ClaudeLog::read_line(self : ClaudeLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) &&
    record.get("message") is Some(Object(message)) &&
    message.get("content") is Some(Array(content)) else {
    return
  }

  match @records.string_field(record, "type") {
    "assistant" => self.read_tool_uses(content)
    "user" => self.read_tool_results(record, content)
    _ => ()
  }
}

///|
fn ClaudeLog::read_tool_uses(self : ClaudeLog, content : Array[Json]) -> Unit {
  for item in content {
    guard item is Object(item) &&
      @records.string_field(item, "type") == "tool_use" &&
      item.get("id") is Some(String(id)) else {
      continue
    }

    let name = @records.string_field(item, "name")
    let input = item.get("input")
    let command = if name == "Bash" && input is Some(Object(input)) {
      @shell.command_head(@records.string_field(input, "command"))
    } else {
      ""
    }
    self.calls[id] = {
      tool: { name, command, },
      input: match input {
        Some(input) => input.stringify()
        None => ""
      },
    }
  }
}

///|
fn ClaudeLog::read_tool_results(
  self : ClaudeLog,
  record : Map[String, Json],
  content : Array[Json],
) -> Unit {
  let session = @records.string_field(record, "sessionId")
  let session = if session.is_empty() { self.fallback_session } else { session }

  for item in content {
    guard item is Object(item) &&
      @records.string_field(item, "type") == "tool_result" &&
      item.get("is_error") is Some(True) &&
      item.get("tool_use_id") is Some(String(id)) else {
      continue
    }
    guard !is_rejection(@records.content_text(item.get("content"))) else {
      continue
    }

    let call = match self.calls.get(id) {
      Some(call) => call
      None => { tool: { name: UNKNOWN_TOOL, command: "", }, input: id, }
    }
    self.report.add_failure(
      id,
      call,
      session~,
      sidechain=record.get("isSidechain") is Some(True),
    )
  }
}
