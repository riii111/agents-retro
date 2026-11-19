///|
pub fn parse_object(line : StringView) -> Map[String, Json]? {
  let json = @json.parse(line) catch { _ => return None }
  guard json is Object(obj) else { return None }

  Some(obj)
}

///|
/// Text of a tool result `content`, which is either a string or a list of text blocks.
pub fn content_text(content : Json?) -> String {
  match content {
    Some(String(s)) => s
    Some(Array(items)) =>
      items
      .filter_map(item => {
        match item {
          Object(item) => Some(string_field(item, "text"))
          _ => None
        }
      })
      .join("\n")
    _ => ""
  }
}

///|
pub fn int_field(obj : Map[String, Json], key : String) -> Int64 {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int64()
    _ => 0L
  }
}

///|
pub fn string_field(obj : Map[String, Json], key : String) -> String {
  match obj.get(key) {
    Some(String(s)) => s
    _ => ""
  }
}
