///|
pub fn parse_object(line : StringView) -> Map[String, Json]? {
  let json = @json.parse(line) catch { _ => return None }
  guard json is Object(obj) else { return None }
  Some(obj)
}

///|
pub fn string_field(obj : Map[String, Json], key : String) -> String {
  match obj.get(key) {
    Some(String(s)) => s
    _ => ""
  }
}
