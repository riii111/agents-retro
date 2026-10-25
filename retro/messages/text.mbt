///|
pub fn take_chars(text : StringView, n : Int32) -> String {
  String::from_iter(text.iter().take(n))
}

///|
pub fn take_last_chars(text : StringView, n : Int32) -> String {
  let chars : Array[Char] = text.iter().collect()

  String::from_array(
    chars[if chars.length() > n { chars.length() - n } else { 0 }:],
  )
}

///|
fn trim(text : StringView) -> String {
  let chars = text.iter().collect()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @whitespace.is_space(chars[start]) {
    start += 1
  }
  while end > start && @whitespace.is_space(chars[end - 1]) {
    end -= 1
  }

  String::from_array(chars[start:end])
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
