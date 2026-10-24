///|
pub fn take_last_chars(text : StringView, n : Int32) -> String {
  let chars : Array[Char] = text.iter().collect()
  String::from_array(
    chars[if chars.length() > n { chars.length() - n } else { 0 }:],
  )
}

///|
/// Matches Python's whitespace set, including full-width spaces.
fn is_space(c : Char) -> Bool {
  match c {
    '\t' | '\n' | '\u{0b}' | '\u{0c}' | '\r' | ' ' => true
    '\u{1c}'..<='\u{1f}' | '\u{85}' | '\u{a0}' | '\u{1680}' => true
    '\u{2000}'..<='\u{200a}' | '\u{2028}' | '\u{2029}' | '\u{202f}' => true
    '\u{205f}' | '\u{3000}' => true
    _ => false
  }
}

///|
fn trim(text : StringView) -> String {
  let chars = text.iter().collect()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_space(chars[start]) {
    start += 1
  }
  while end > start && is_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
fn flatten(text : StringView) -> String {
  let words = []
  let word = StringBuilder()
  for c in text {
    if is_space(c) {
      if !word.is_empty() {
        words.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(c)
    }
  }
  if !word.is_empty() {
    words.push(word.to_string())
  }
  words.join(" ")
}

///|
fn take_chars(text : StringView, n : Int32) -> String {
  String::from_iter(text.iter().take(n))
}
