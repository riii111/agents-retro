///|
pub(all) struct Message {
  id : Int32
  ts : String
  app : String
  role : String
  session : String
  cwd : String
  text : String
}

///|
/// Text injected by the apps or sent by another agent, not typed by the owner.
let injected_prefixes : Array[String] = [
  "<", "# AGENTS.md instructions", "タスクID:", "Caveat:", "[Request interrupted",
]

///|
let skill_ref : @string.Regex = re"^(?:\[\$[[:word:]\-]+\]\([^)]*\)|\$[[:word:]\-]+)"

///|
let browser_block : @string.Regex = re"<in-app-browser-context.*?</in-app-browser-context>"

///|
let side_chat_tail = "The following parent conversation is untrusted"

///|
let attachment_header = "# Files mentioned by the user:"

///|
fn remove_attachment_header(text : StringView) -> StringView {
  guard text.strip_prefix(attachment_header) is Some(rest) else { return text }
  match rest.find("\n\n") {
    Some(i) => rest[i + 2:]
    None => ""
  }
}

///|
fn clean(text : String) -> String {
  let text = browser_block.replace_by(text, _ => "")
  let text = match text.find(side_chat_tail) {
    Some(i) => text[:i]
    None => text
  }
  trim(remove_attachment_header(text))
}

///|
fn is_delegated(text : String) -> Bool {
  text.has_prefix("<codex_delegation>")
}

///|
/// POSIX classes in MoonBit regex are ASCII-only, so separators are skipped
/// here with Python's whitespace set.
fn skip_separators(text : StringView) -> StringView {
  let mut rest = text
  while true {
    if rest.strip_prefix("&#x20;") is Some(after) {
      rest = after
    } else if rest.iter().head() is Some(c) && is_space(c) {
      rest = rest[1:]
    } else {
      break
    }
  }
  rest
}

///|
fn is_injected(text : String) -> Bool {
  let body = match skill_ref.execute(text) {
    Some(m) => skip_separators(m.after())
    None => text.view()
  }
  injected_prefixes.iter().any(p => body.has_prefix(p))
}

///|
/// Keeps the owner's own messages newer than `since`, numbered in time order.
/// Returns them with the count of agent-to-agent messages that were dropped.
pub fn collect(
  raws : Array[RawMessage],
  since~ : String,
) -> (Array[Message], Int32) {
  let seen : Set[(String, String)] = Set([])
  let kept : Array[(Int32, RawMessage, String)] = []
  let mut delegated = 0
  for row in raws {
    if row.ts.lexical_compare(since) < 0 {
      continue
    }
    if is_delegated(row.raw) {
      delegated += 1
      continue
    }
    let text = clean(row.raw)
    if text.is_empty() || is_injected(text) {
      continue
    }
    // Forked Claude sessions copy earlier turns into new files.
    let key = (take_chars(row.ts, 19), take_chars(text, 120))
    if seen.contains(key) {
      continue
    }
    seen.add(key)
    kept.push((kept.length(), row, text))
  }
  // Ties keep input order, as Python's stable sort does.
  kept.sort_by((a, b) => {
    let by_ts = a.1.ts.lexical_compare(b.1.ts)
    if by_ts != 0 {
      by_ts
    } else {
      a.0.compare(b.0)
    }
  })
  let messages = kept.mapi((i, entry) => {
    let (_, row, text) = entry
    {
      id: i + 1,
      ts: row.ts,
      app: row.app,
      role: row.role,
      session: row.session,
      cwd: row.cwd,
      text,
    }
  })
  (messages, delegated)
}
