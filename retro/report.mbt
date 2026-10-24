///|
pub(all) struct PatternCount {
  name : String
  messages : Int32
  sessions : Int32
}

///|
pub(all) struct PatternHits {
  name : String
  messages : Array[Message]
}

///|
/// Files other than `messages.tsv` carry only a head and tail of each message so that reading them costs a bounded amount of context.
let preview_head = 140

///|
let preview_tail = 60

///|
let examples_per_pattern = 3

///|
let unmatched_chunk_rows = 100

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
pub fn match_patterns(
  messages : Array[Message],
  patterns : Array[(String, @string.Regex)],
) -> Array[PatternHits] {
  patterns.map(entry => {
    let (name, regex) = entry
    { name, messages: messages.filter(m => regex.execute(m.text) is Some(_)), }
  })
}

///|
pub fn count_patterns(hits : Array[PatternHits]) -> Array[PatternCount] {
  hits.map(h => {
    name: h.name,
    messages: h.messages.length(),
    sessions: session_count(h.messages),
  })
}

///|
/// Takes examples from distinct sessions so one long conversation cannot dominate.
pub fn pattern_examples(hits : Array[PatternHits]) -> Array[(String, Message)] {
  let examples = []
  for h in hits {
    let seen : Set[(String, String)] = Set([])
    for m in h.messages {
      if seen.length() == examples_per_pattern {
        break
      }
      if seen.contains(session_key(m)) {
        continue
      }
      seen.add(session_key(m))
      examples.push((h.name, m))
    }
  }
  examples
}

///|
pub fn unmatched_chunks(
  messages : Array[Message],
  hits : Array[PatternHits],
) -> Array[Array[Message]] {
  let matched : Set[Int32] = Set([])
  for h in hits {
    for m in h.messages {
      matched.add(m.id)
    }
  }
  let unmatched = messages.filter(m => !matched.contains(m.id))
  let chunks = []
  for start = 0
      start < unmatched.length()
      start = start + unmatched_chunk_rows {
    let end = if start + unmatched_chunk_rows < unmatched.length() {
      start + unmatched_chunk_rows
    } else {
      unmatched.length()
    }
    chunks.push(unmatched[start:end].to_owned())
  }
  chunks
}

///|
pub fn session_count(messages : Array[Message]) -> Int32 {
  Set::from_iter(messages.iter().map(session_key)).length()
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

///|
pub fn example_tsv_line(name : String, m : Message) -> String {
  [name, m.id.to_string(), m.session, preview(m.text)].join("\t")
}

///|
pub fn unmatched_tsv_line(m : Message) -> String {
  [m.id.to_string(), preview(m.text)].join("\t")
}

///|
fn preview(text : String) -> String {
  let flat = flatten(text)
  let length = flat.char_length()
  if length <= preview_head + preview_tail {
    return flat
  }
  "\{take_chars(flat, preview_head)} …[\{length}字]… \{take_last_chars(flat, preview_tail)}"
}

///|
fn session_key(m : Message) -> (String, String) {
  (m.app, m.session)
}
