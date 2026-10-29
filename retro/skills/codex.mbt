///|
pub struct CodexLog {
  priv report : Report
  priv mut session : String
  priv mut sidechain : Bool
  priv since : String
}

///|
pub fn is_codex_candidate(line : BytesView) -> Bool {
  line.find(b"\"session_meta\"") is Some(_) ||
  (
    line.find(b"\"role\":\"user\"") is Some(_) &&
    line.find(b"SKILL.md)") is Some(_)
  )
}

///|
pub fn Report::codex_log(
  self : Report,
  session~ : String,
  since~ : String,
) -> CodexLog {
  { report: self, session, sidechain: false, since, }
}

///|
pub fn CodexLog::read_line(self : CodexLog, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) &&
    record.get("payload") is Some(Object(payload)) else {
    return
  }

  match @records.string_field(record, "type") {
    "session_meta" => self.read_meta(payload)
    "response_item" =>
      if @clock.in_period(
          @records.string_field(record, "timestamp"),
          since=self.since,
        ) {
        self.read_item(payload)
      }
    _ => ()
  }
}

///|
fn CodexLog::read_meta(self : CodexLog, payload : Map[String, Json]) -> Unit {
  let id = @records.string_field(payload, "id")
  if !id.is_empty() {
    self.session = id
  }

  if payload.get("source") is Some(Object(source)) {
    self.sidechain = source.contains("subagent")
  }
}

///|
/// A skill is called by a `[$name](.../name/SKILL.md)` link in a user message.
fn CodexLog::read_item(self : CodexLog, payload : Map[String, Json]) -> Unit {
  guard @records.string_field(payload, "type") == "message" &&
    @records.string_field(payload, "role") == "user" &&
    payload.get("content") is Some(Array(content)) else {
    return
  }

  for item in content {
    guard item is Object(item) else { continue }

    for name in skill_links(@records.string_field(item, "text")) {
      self.report.add_skill(
        source="codex",
        name~,
        via="mention",
        session=self.session,
        sidechain=self.sidechain,
      )
    }
  }
}

///|
fn skill_links(text : String) -> Array[String] {
  let names = []
  let mut rest = text[:]
  while rest.split_once("[$") is Some((_, after)) {
    rest = after
    guard after.split_once("](") is Some((name, tail)) &&
      tail.split_once(")") is Some((path, next)) &&
      !name.is_empty() &&
      path.has_suffix("/\{name}/SKILL.md") else {
      continue
    }

    names.push(name.to_owned())
    rest = next
  }

  names
}
