///|
pub struct ClaudeLog {
  priv report : Report
  priv fallback_session : String
  priv since : String
  priv bash_commands : Map[String, String]
}

///|
let hook_error_marker : String = " hook error: "

///|
pub fn is_claude_candidate(line : BytesView) -> Bool {
  line.find(b"hook error: ") is Some(_) ||
  line.find(b"\"hook_blocking_error\"") is Some(_) ||
  line.find(b"\"name\":\"Bash\"") is Some(_)
}

///|
pub fn Report::claude_log(
  self : Report,
  session~ : String,
  since~ : String,
) -> ClaudeLog {
  { report: self, fallback_session: session, since, bash_commands: Map([]), }
}

///|
/// Records before `since` still restore the Bash command table, but add no blocks.
pub fn ClaudeLog::read_line(self : ClaudeLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) else { return }

  let counted = @clock.in_period(
    @records.string_field(record, "timestamp"),
    since=self.since,
  )
  match @records.string_field(record, "type") {
    "assistant" => self.read_assistant(record)
    "user" => if counted { self.read_user(record) }
    "attachment" => if counted { self.read_attachment(record) }
    _ => ()
  }
}

///|
fn ClaudeLog::read_assistant(
  self : ClaudeLog,
  record : Map[String, Json],
) -> Unit {
  guard record.get("message") is Some(Object(message)) &&
    message.get("content") is Some(Array(content)) else {
    return
  }

  for item in content {
    guard item is Object(item) &&
      @records.string_field(item, "type") == "tool_use" &&
      @records.string_field(item, "name") == "Bash" &&
      item.get("id") is Some(String(id)) &&
      item.get("input") is Some(Object(input)) else {
      continue
    }

    self.bash_commands[id] = @shell.command_head(
      @records.string_field(input, "command"),
    )
  }
}

///|
/// A PreToolUse block comes back to the model as an error tool result.
fn ClaudeLog::read_user(self : ClaudeLog, record : Map[String, Json]) -> Unit {
  guard record.get("message") is Some(Object(message)) &&
    message.get("content") is Some(Array(content)) else {
    return
  }

  for item in content {
    guard item is Object(item) &&
      @records.string_field(item, "type") == "tool_result" &&
      item.get("is_error") is Some(True) &&
      item.get("tool_use_id") is Some(String(id)) &&
      parse_hook_error(@records.content_text(item.get("content")))
      is Some((event, tool, message)) else {
      continue
    }

    self.report.add_block(id, {
      event,
      tool,
      command: self.bash_commands.get(id).unwrap_or(""),
      message,
      session: self.session_of(record),
      sidechain: is_sidechain(record),
    })
  }
}

///|
/// A Stop hook that refuses to let the model finish is logged as an attachment.
fn ClaudeLog::read_attachment(
  self : ClaudeLog,
  record : Map[String, Json],
) -> Unit {
  guard record.get("attachment") is Some(Object(attachment)) &&
    @records.string_field(attachment, "type") == "hook_blocking_error" &&
    attachment.get("blockingError") is Some(Object(blocking)) else {
    return
  }

  let event = @records.string_field(attachment, "hookEvent")
  let hook_name = @records.string_field(attachment, "hookName")
  let tool = match hook_name.find(":") {
    Some(i) => hook_name[i + 1:].to_owned()
    None => ""
  }
  self.report.add_block(@records.string_field(record, "uuid"), {
    event,
    tool,
    command: "",
    message: first_line(@records.string_field(blocking, "blockingError")),
    session: self.session_of(record),
    sidechain: is_sidechain(record),
  })
}

///|
fn ClaudeLog::session_of(
  self : ClaudeLog,
  record : Map[String, Json],
) -> String {
  let session = @records.string_field(record, "sessionId")
  if session.is_empty() {
    self.fallback_session
  } else {
    session
  }
}

///|
fn is_sidechain(record : Map[String, Json]) -> Bool {
  record.get("isSidechain") is Some(True)
}

///|
/// Splits `<event>:<tool> hook error: <message>` into its parts.
fn parse_hook_error(text : String) -> (String, String, String)? {
  guard text.find(hook_error_marker) is Some(i) else { return None }

  let prefix = text[:i]
  guard prefix.find(":") is Some(colon) &&
    !prefix.iter().any(@whitespace.is_space) else {
    return None
  }

  Some(
    (
      prefix[:colon].to_owned(),
      prefix[colon + 1:].to_owned(),
      first_line(text[i + hook_error_marker.length():].to_owned()),
    ),
  )
}

///|
/// Hook messages often carry variable detail after the first line.
fn first_line(text : String) -> String {
  let line = match text.find("\n") {
    Some(i) => text[:i].to_owned()
    None => text
  }

  line.trim().to_owned()
}
