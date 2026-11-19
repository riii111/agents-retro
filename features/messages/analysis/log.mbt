///|
struct RawMessage {
  ts : String
  app : String
  role : String
  session : String
  cwd : String
  raw : String
}

///|
let codex_human_sources : Array[String] = [
  "user", "agent_created_thread", "automation",
]

///|
/// The project directory name encodes the original working directory.
pub fn claude_message(
  line : StringView,
  project~ : String,
  session~ : String,
) -> RawMessage? {
  guard @records.parse_object(line) is Some(d) else { return None }
  if !(d.get("type") is Some(String("user"))) ||
    d.get("isMeta") is Some(True) ||
    d.get("isSidechain") is Some(True) {
    return None
  }

  let content = match d.get("message") {
    Some(Object(m)) => claude_content(m.get("content"))
    _ => None
  }
  guard content is Some(raw) && !is_blank(raw) else { return None }

  Some({
    ts: @records.string_field(d, "timestamp"),
    app: "claude",
    role: if project.contains("-codex-worktrees-") {
      "worker"
    } else {
      "main"
    },
    session,
    cwd: @records.string_field(d, "cwd"),
    raw,
  })
}

///|
/// Reads a Codex log line by line, carrying the thread source and working directory from the last session metadata line.
pub struct CodexSession {
  session : String
  mut source : String?
  mut cwd : String
}

///|
pub fn CodexSession::new(session : String) -> CodexSession {
  { session, source: None, cwd: "", }
}

///|
/// Includes user, automation, and agent-created threads; labels the last as workers.
pub fn CodexSession::read_line(
  self : CodexSession,
  line : StringView,
) -> RawMessage? {
  guard @records.parse_object(line) is Some(d) else { return None }
  let payload = match d.get("payload") {
    Some(Object(p)) => p
    _ => Map([])
  }

  let kind = @records.string_field(d, "type")
  if kind == "session_meta" {
    self.source = match payload.get("thread_source") {
      Some(String(s)) => Some(s)
      _ => None
    }
    self.cwd = @records.string_field(payload, "cwd")
    return None
  }

  guard self.source is Some(src) && codex_human_sources.contains(src) else {
    return None
  }
  if kind != "response_item" || @records.string_field(payload, "role") != "user" {
    return None
  }

  let texts = []
  if payload.get("content") is Some(Array(items)) {
    for item in items {
      if item is Object(c) {
        texts.push(@records.string_field(c, "text"))
      }
    }
  }

  let raw = texts.join(" ")
  if is_blank(raw) {
    return None
  }

  Some({
    ts: @records.string_field(d, "timestamp"),
    app: "codex",
    role: if src == "agent_created_thread" {
      "worker"
    } else {
      src
    },
    session: self.session,
    cwd: self.cwd,
    raw,
  })
}

///|
/// Narrows lines before JSON parsing to save memory and time, keeping every line that could hold a user turn or Codex session metadata.
/// Lines with `\u` escapes stay because an escaped value such as `"\u0075ser"` parses as `"user"`.
pub fn is_candidate_line(line : BytesView) -> Bool {
  line.find(b"\"user\"") is Some(_) ||
  line.find(b"\"session_meta\"") is Some(_) ||
  line.find(b"\\u") is Some(_)
}

///|
fn is_blank(text : String) -> Bool {
  text.iter().all(@whitespace.is_space)
}

///|
fn claude_content(content : Json?) -> String? {
  match content {
    Some(String(s)) => Some(s)
    Some(Array(items)) => {
      let texts = []
      for item in items {
        if item is Object(c) && c.get("type") is Some(String("text")) {
          texts.push(@records.string_field(c, "text"))
        }
      }

      Some(texts.join(" "))
    }
    _ => None
  }
}
