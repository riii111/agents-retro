///|
pub fn take_chars(text : StringView, n : Int32) -> String {
  String::from_iter(text.iter().take(n))
}

///|
pub fn take_last_chars(text : StringView, n : Int32) -> String {
  let chars : Array[Char] = text.rev_iter().take(n).collect()
  chars.rev_in_place()
  String::from_array(chars)
}

///|
/// Trims the Python `str.isspace` set from both ends without expanding the whole text.
fn trim(text : StringView) -> String {
  let mut start = 0
  for c in text {
    if !@whitespace.is_space(c) {
      break
    }
    start += c.utf16_len()
  }

  let mut end = text.length()
  for c in text[start:].rev_iter() {
    if !@whitespace.is_space(c) {
      break
    }
    end -= c.utf16_len()
  }

  text[start:end].to_owned()
}

///|
fn flatten(text : StringView) -> String {
  let words = []
  let word = StringBuilder()
  for c in text {
    if @whitespace.is_space(c) {
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
