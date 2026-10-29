///|
pub struct CodexLog {
  priv report : Report
  priv calls : Map[String, Tool]
  priv mut session : String
  priv mut project : String
  priv mut sidechain : Bool
  priv mut previous : Tool
}

///|
pub fn is_codex_candidate(line : BytesView) -> Bool {
  line.find(b"\"session_meta\"") is Some(_) ||
  line.find(b"\"token_usage_record\"") is Some(_) ||
  line.find(b"_call") is Some(_) ||
  line.find(b"\"role\":\"user\"") is Some(_)
}

///|
pub fn Report::codex_log(self : Report, session~ : String) -> CodexLog {
  {
    report: self,
    calls: Map([]),
    session,
    project: "(unknown)",
    sidechain: false,
    previous: prompt,
  }
}

///|
/// Token usage is read from `token_usage_record` lines, which carry one entry per model response.
pub fn CodexLog::read_line(self : CodexLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) &&
    record.get("payload") is Some(Object(payload)) else {
    return
  }

  match @records.string_field(record, "type") {
    "session_meta" => self.read_meta(payload)
    "token_usage_record" => self.read_usage(payload)
    "response_item" => self.read_item(payload)
    _ => ()
  }
}

///|
fn CodexLog::read_meta(self : CodexLog, payload : Map[String, Json]) -> Unit {
  let id = @records.string_field(payload, "id")
  if !id.is_empty() {
    self.session = id
  }

  let cwd = @records.string_field(payload, "cwd")
  if !cwd.is_empty() {
    self.project = cwd
  }

  if payload.get("source") is Some(Object(source)) {
    self.sidechain = source.contains("subagent")
  }
}

///|
fn CodexLog::read_usage(self : CodexLog, payload : Map[String, Json]) -> Unit {
  guard payload.get("usage") is Some(Object(usage)) else { return }

  let cached = @records.int_field(usage, "cached_input_tokens")
  self.report.add_response(
    @records.string_field(payload, "response_id"),
    source="codex",
    session=self.session,
    project=self.project,
    sidechain=self.sidechain,
    previous=self.previous,
    {
      input: @records.int_field(usage, "input_tokens") - cached,
      cache_creation: @records.int_field(usage, "cache_write_input_tokens"),
      cache_read: cached,
      output: @records.int_field(usage, "output_tokens"),
    },
  )
}

///|
fn CodexLog::read_item(self : CodexLog, payload : Map[String, Json]) -> Unit {
  match @records.string_field(payload, "type") {
    "function_call" | "custom_tool_call" =>
      if payload.get("call_id") is Some(String(id)) {
        self.calls[id] = {
          name: @records.string_field(payload, "name"),
          command: "",
        }
      }
    "function_call_output" | "custom_tool_call_output" =>
      if payload.get("call_id") is Some(String(id)) &&
        self.calls.get(id) is Some(tool) {
        self.report.add_result(
          id,
          source="codex",
          tool,
          @records.content_text(payload.get("output")).length(),
        )
        self.previous = tool
      }
    "message" =>
      if @records.string_field(payload, "role") == "user" {
        self.previous = prompt
      }
    _ => ()
  }
}
