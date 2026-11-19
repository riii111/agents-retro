///|
pub struct ClaudeLog {
  priv report : Report
  priv fallback_session : String
  priv since : String
}

///|
pub fn is_claude_candidate(line : BytesView) -> Bool {
  line.find(b"\"name\":\"Skill\",\"input\"") is Some(_) ||
  line.find(b"\"subagent_type\":\"") is Some(_) ||
  line.find(b"<command-name>") is Some(_)
}

///|
pub fn Report::claude_log(
  self : Report,
  session~ : String,
  since~ : String,
) -> ClaudeLog {
  { report: self, fallback_session: session, since, }
}

///|
pub fn ClaudeLog::read_line(self : ClaudeLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) &&
    record.get("message") is Some(Object(message)) else {
    return
  }

  guard @clock.in_period(
    @records.string_field(record, "timestamp"),
    since=self.since,
  ) else {
    return
  }

  let id = @records.string_field(record, "sessionId")
  let session = if id.is_empty() { self.fallback_session } else { id }
  let sidechain = record.get("isSidechain") is Some(True)

  match @records.string_field(record, "type") {
    "assistant" => self.read_assistant(message, session~, sidechain~)
    "user" =>
      self.read_user(
        @records.string_field(record, "uuid"),
        message,
        session~,
        sidechain~,
      )
    _ => ()
  }
}

///|
fn ClaudeLog::read_assistant(
  self : ClaudeLog,
  message : Map[String, Json],
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  guard message.get("content") is Some(Array(content)) else { return }

  for item in content {
    guard item is Object(item) &&
      @records.string_field(item, "type") == "tool_use" &&
      item.get("input") is Some(Object(input)) &&
      self.report.first_seen(@records.string_field(item, "id")) else {
      continue
    }

    match @records.string_field(item, "name") {
      "Skill" => {
        let name = @records.string_field(input, "skill")
        if !name.is_empty() {
          self.report.add_skill(
            source="claude",
            name~,
            via="skill_tool",
            session~,
            sidechain~,
          )
        }
      }
      "Agent" | "Task" => {
        let subagent_type = @records.string_field(input, "subagent_type")
        if !subagent_type.is_empty() {
          self.report.add_subagent(
            source="claude",
            subagent_type~,
            session~,
            sidechain~,
          )
        }
      }
      _ => ()
    }
  }
}

///|
fn ClaudeLog::read_user(
  self : ClaudeLog,
  uuid : String,
  message : Map[String, Json],
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  let texts = match message.get("content") {
    Some(String(text)) => [text]
    Some(Array(content)) =>
      content.filter_map(item => {
        match item {
          Object(item) if @records.string_field(item, "type") == "text" =>
            Some(@records.string_field(item, "text"))
          _ => None
        }
      })
    _ => []
  }

  let names = texts.filter_map(text => {
    match slash_command(text) {
      Some(name) if !builtin_commands.contains(name) => Some(name)
      _ => None
    }
  })
  guard !names.is_empty() && self.report.first_record(uuid) else { return }

  for name in names {
    self.report.add_skill(
      source="claude",
      name~,
      via="slash_command",
      session~,
      sidechain~,
    )
  }
}

///|
/// A typed `/<name>` is recorded as a message that opens with the command tags.
fn slash_command(text : String) -> String? {
  let text = text.trim_start()
  guard text.has_prefix("<command-name>") ||
    text.has_prefix("<command-message>") else {
    return None
  }
  guard text.split_once("<command-name>") is Some((_, rest)) &&
    rest.split_once("</command-name>") is Some((name, _)) else {
    return None
  }

  let name = name.trim().trim_start(chars="/").to_owned()
  if name.is_empty() {
    None
  } else {
    Some(name)
  }
}
