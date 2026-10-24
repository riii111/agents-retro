///|
pub(all) struct RawMessage {
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
pub fn claude_messages(
  lines : Array[String],
  project~ : String,
  session~ : String,
) -> Array[RawMessage] {
  let role = if project.contains("-codex-worktrees-") {
    "worker"
  } else {
    "main"
  }
  let rows = []
  for line in lines {
    guard parse_object(line) is Some(d) else { continue }
    if !(d.get("type") is Some(String("user"))) ||
      d.get("isMeta") is Some(True) ||
      d.get("isSidechain") is Some(True) {
      continue
    }
    let content = match d.get("message") {
      Some(Object(m)) => claude_content(m.get("content"))
      _ => None
    }
    guard content is Some(raw) && !is_blank(raw) else { continue }
    rows.push({
      ts: string_field(d, "timestamp"),
      app: "claude",
      role,
      session,
      cwd: string_field(d, "cwd"),
      raw,
    })
  }
  rows
}

///|
/// Includes user, automation, and agent-created threads; labels the last as workers.
pub fn codex_messages(
  lines : Array[String],
  session~ : String,
) -> Array[RawMessage] {
  let rows = []
  let mut source : String? = None
  let mut cwd = ""
  for line in lines {
    guard parse_object(line) is Some(d) else { continue }
    let payload = match d.get("payload") {
      Some(Object(p)) => p
      _ => Map([])
    }
    let kind = string_field(d, "type")
    if kind == "session_meta" {
      source = match payload.get("thread_source") {
        Some(String(s)) => Some(s)
        _ => None
      }
      cwd = string_field(payload, "cwd")
      continue
    }
    guard source is Some(src) && codex_human_sources.contains(src) else {
      continue
    }
    if kind != "response_item" || string_field(payload, "role") != "user" {
      continue
    }
    let texts = []
    if payload.get("content") is Some(Array(items)) {
      for item in items {
        if item is Object(c) {
          texts.push(string_field(c, "text"))
        }
      }
    }
    let raw = texts.join(" ")
    if is_blank(raw) {
      continue
    }
    rows.push({
      ts: string_field(d, "timestamp"),
      app: "codex",
      role: if src == "agent_created_thread" {
        "worker"
      } else {
        src
      },
      session,
      cwd,
      raw,
    })
  }
  rows
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
fn parse_object(line : StringView) -> Map[String, Json]? {
  let json = @json.parse(line) catch { _ => return None }
  guard json is Object(obj) else { return None }
  Some(obj)
}

///|
fn string_field(obj : Map[String, Json], key : String) -> String {
  match obj.get(key) {
    Some(String(s)) => s
    _ => ""
  }
}

///|
fn is_blank(text : String) -> Bool {
  text.iter().all(is_space)
}

///|
fn claude_content(content : Json?) -> String? {
  match content {
    Some(String(s)) => Some(s)
    Some(Array(items)) => {
      let texts = []
      for item in items {
        if item is Object(c) && c.get("type") is Some(String("text")) {
          texts.push(string_field(c, "text"))
        }
      }
      Some(texts.join(" "))
    }
    _ => None
  }
}
