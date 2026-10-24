///|
pub(all) struct PatternCount {
  name : String
  messages : Int32
  sessions : Int32
}

///|
fn session_key(m : Message) -> (String, String) {
  (m.app, m.session)
}

///|
pub fn session_count(messages : Array[Message]) -> Int32 {
  Set::from_iter(messages.iter().map(session_key)).length()
}

///|
/// Preserves category order from the JSON object.
pub fn parse_patterns(source : String) -> Array[(String, @string.Regex)] raise {
  guard @json.parse(source) is Object(obj) else {
    fail("patterns must be a JSON object of category name to regex")
  }
  let patterns = []
  for name, value in obj {
    guard value is String(pattern) else {
      fail("pattern \{name} must be a string")
    }
    patterns.push((name, @string.Regex(pattern)))
  }
  patterns
}

///|
pub fn count_patterns(
  messages : Array[Message],
  patterns : Array[(String, @string.Regex)],
) -> Array[PatternCount] {
  patterns.map(entry => {
    let (name, regex) = entry
    let hits = messages.filter(m => regex.execute(m.text) is Some(_))
    { name, messages: hits.length(), sessions: session_count(hits), }
  })
}

///|
/// Message counts per `app/role`, sorted by key.
pub fn count_by_role(messages : Array[Message]) -> Array[(String, Int32)] {
  let counts : Map[String, Int32] = Map([])
  for m in messages {
    let key = "\{m.app}/\{m.role}"
    counts[key] = counts.get_or_default(key, 0) + 1
  }
  let keys = counts.keys().collect()
  keys.sort_by((a, b) => a.lexical_compare(b))
  keys.map(k => (k, counts[k]))
}

///|
pub fn message_tsv_line(m : Message) -> String {
  [
    m.id.to_string(),
    take_chars(m.ts, 16),
    m.app,
    m.role,
    m.session,
    m.cwd,
    flatten(m.text),
  ].join("\t")
}
