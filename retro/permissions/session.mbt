///|
struct Call {
  head : String
  unsandboxed : Bool
}

///|
pub struct Session {
  priv report : Report
  priv calls : Map[String, Call]
}

///|
let write_errors : @string.Regex = regex(
  "Operation not permitted|Read-only file system|attempt to write a readonly database",
)

///|
let quoted_path : @string.Regex = regex(
  "'(/[^'\n]+)'|\"(/[^\"\n]+)\"|(?:on|in|create|open) (/[^\{whitespace_chars}:'\")]+)",
)

///|
let network : @string.Regex = regex(
  "deny network-outbound ([^\{whitespace_chars}:\\\\]+)",
)

///|
pub fn is_candidate_line(line : BytesView) -> Bool {
  line.find(b"\"tool_use\"") is Some(_) ||
  line.find(b"\"tool_result\"") is Some(_) ||
  line.find(b"\\u") is Some(_)
}

///|
pub fn Report::start_session(self : Report) -> Session {
  { report: self, calls: Map([]), }
}

///|
pub fn Session::read_line(self : Session, line : StringView) -> Unit {
  guard @records.parse_object(line) is Some(record) else { return }
  guard record.get("message") is Some(Object(message)) &&
    message.get("content") is Some(Array(content)) else {
    return
  }

  let report = self.report
  for item in content {
    guard item is Object(item) else { continue }

    if @records.string_field(item, "type") == "tool_use" &&
      @records.string_field(item, "name") == "Bash" {
      guard item.get("id") is Some(String(id)) &&
        item.get("input") is Some(Object(input)) else {
        continue
      }

      let call : Call = {
        head: @shell.command_head(@records.string_field(input, "command")),
        unsandboxed: input.get("dangerouslyDisableSandbox") is Some(True),
      }
      self.calls[id] = call
      if call.unsandboxed {
        report.reruns.add(call.head)
      }
    } else if @records.string_field(item, "type") == "tool_result" {
      guard item.get("tool_use_id") is Some(String(id)) &&
        self.calls.get(id) is Some(call) &&
        !call.unsandboxed else {
        continue
      }

      let output = @records.content_text(item.get("content"))
      for m in network.find(output) {
        if m.group(1) is Some(host) {
          report.hosts.add(host.to_owned())
        }
      }

      if write_errors.execute(output) is None {
        continue
      }

      report.failed.add(call.head)
      for line in output.split("\n") {
        if write_errors.execute(line) is None {
          continue
        }

        for m in quoted_path.find(line) {
          for i in 1..<4 {
            if m.group(i) is Some(path) {
              report.writes.add(path_prefix(path.to_owned(), report.home))
              break
            }
          }
        }
      }
    }
  }
}

///|
fn path_prefix(path : String, home : String) -> String {
  if path == home {
    return "~"
  }

  if path.find("/.git/") is Some(i) {
    return replace_home(path[:i].to_owned() + "/.git", home)
  }

  if path.strip_prefix(home + "/") is Some(rest) {
    let parts : Array[StringView] = rest.split("/").take(3).collect()
    return "~/" + parts.join("/")
  }

  let parts : Array[StringView] = path.split("/").take(4).collect()
  parts.join("/")
}
