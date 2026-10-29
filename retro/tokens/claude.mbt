///|
pub struct ClaudeLog {
  priv report : Report
  priv fallback_session : String
  priv calls : Map[String, Tool]
  priv mut previous : Tool
}

///|
let prompt : Tool = { name: "(user prompt)", command: "", }

///|
pub fn is_claude_candidate(line : BytesView) -> Bool {
  line.find(b"\"usage\"") is Some(_) ||
  line.find(b"\"role\":\"user\"") is Some(_)
}

///|
pub fn Report::claude_log(self : Report, session~ : String) -> ClaudeLog {
  { report: self, fallback_session: session, calls: Map([]), previous: prompt, }
}

///|
pub fn ClaudeLog::read_line(self : ClaudeLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) &&
    record.get("message") is Some(Object(message)) else {
    return
  }

  match @records.string_field(record, "type") {
    "assistant" => self.read_assistant(record, message)
    "user" => self.read_user(message)
    _ => ()
  }
}

///|
fn ClaudeLog::read_assistant(
  self : ClaudeLog,
  record : Map[String, Json],
  message : Map[String, Json],
) -> Unit {
  if message.get("content") is Some(Array(content)) {
    for item in content {
      guard item is Object(item) &&
        @records.string_field(item, "type") == "tool_use" &&
        item.get("id") is Some(String(id)) else {
        continue
      }

      let name = @records.string_field(item, "name")
      let command = if name == "Bash" &&
        item.get("input") is Some(Object(input)) {
        @shell.command_head(@records.string_field(input, "command"))
      } else {
        ""
      }
      self.calls[id] = { name, command, }
    }
  }

  guard message.get("usage") is Some(Object(usage)) else { return }

  let session = @records.string_field(record, "sessionId")
  let project = @records.string_field(record, "cwd")
  self.report.add_response(
    @records.string_field(message, "id"),
    source="claude",
    session=if session.is_empty() { self.fallback_session } else { session },
    project=if project.is_empty() { "(unknown)" } else { project },
    sidechain=record.get("isSidechain") is Some(True),
    previous=self.previous,
    {
      input: @records.int_field(usage, "input_tokens"),
      cache_creation: @records.int_field(usage, "cache_creation_input_tokens"),
      cache_read: @records.int_field(usage, "cache_read_input_tokens"),
      output: @records.int_field(usage, "output_tokens"),
    },
  )
}

///|
fn ClaudeLog::read_user(self : ClaudeLog, message : Map[String, Json]) -> Unit {
  match message.get("content") {
    Some(String(_)) => self.previous = prompt
    Some(Array(content)) =>
      for item in content {
        guard item is Object(item) else { continue }

        if @records.string_field(item, "type") != "tool_result" {
          self.previous = prompt
          continue
        }

        guard item.get("tool_use_id") is Some(String(id)) &&
          self.calls.get(id) is Some(tool) else {
          continue
        }

        self.report.add_result(
          id,
          source="claude",
          tool,
          @records.content_text(item.get("content")).length(),
        )
        self.previous = tool
      }
    _ => ()
  }
}
