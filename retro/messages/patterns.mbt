///|
struct PatternHits {
  name : String
  messages : Array[Message]
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
pub fn match_patterns(
  messages : Array[Message],
  patterns : Array[(String, @string.Regex)],
) -> Array[PatternHits] {
  patterns.map(entry => {
    let (name, regex) = entry
    { name, messages: messages.filter(m => regex.execute(m.text) is Some(_)), }
  })
}
