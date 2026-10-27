///|
let command_openers : Array[String] = [
  "if", "elif", "then", "else", "do", "while", "until", "!", "{",
]

///|
let non_commands : Array[String] = [
  "for", "select", "function", "fi", "done", "esac", "}",
]

///|
pub fn command_head(command : String) -> String {
  for words in split_segments(command) {
    guard command_start(words) is Some(start) else { continue }
    let head = words[start]
    if ["git", "gh", "bun", "bunx", "npm", "npx", "cargo", "go", "nix", "uv"].contains(
        head,
      ) {
      let mut i = start + 1
      while i < words.length() {
        if words[i] == "-C" {
          i += 2
          continue
        }
        if !words[i].has_prefix("-") {
          return "\{head} \{words[i]}"
        }
        i += 1
      }
    }

    return head
  }

  ""
}

///|
fn command_start(words : Array[String]) -> Int32? {
  let mut start = 0
  while start < words.length() {
    let word = words[start]
    if is_assignment(word) ||
      word == "env" ||
      command_openers.contains(word) ||
      is_case_pattern(word) {
      start += 1
    } else if word == "-u" {
      start += 2
    } else if word == "case" {
      match case_body_start(words, start + 1) {
        Some(body) => start = body
        None => return None
      }
    } else {
      break
    }
  }

  if start >= words.length() {
    return None
  }

  let head = words[start]
  if head == "cd" || head.has_prefix("((") || non_commands.contains(head) {
    None
  } else {
    Some(start)
  }
}

///|
fn case_body_start(words : Array[String], from : Int32) -> Int32? {
  let mut i = from
  while i < words.length() && words[i] != "in" {
    i += 1
  }
  while i < words.length() && !words[i].has_suffix(")") {
    i += 1
  }

  if i < words.length() {
    Some(i + 1)
  } else {
    None
  }
}

///|
fn is_case_pattern(word : String) -> Bool {
  word.has_suffix(")") && !word.contains("(")
}

///|
fn is_assignment(word : String) -> Bool {
  let mut length = 0
  for c in word {
    if c == '=' {
      return length > 0
    }
    let letter = c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
    let digit = c >= '0' && c <= '9'
    if !(letter || (digit && length > 0)) {
      return false
    }
    length += 1
  }

  false
}

///|
/// Splits at `&&`, `;` and newlines outside quotes and `((...))`; quotes stay in words.
fn split_segments(command : String) -> Array[Array[String]] {
  let chars = command.iter().collect()
  let segments = []
  let words = []
  let word = StringBuilder()
  let mut quote : Char? = None
  let mut arithmetic = 0
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let next = chars.get(i + 1)
    if quote is Some(q) {
      if c == '\\' && q == '"' && next is Some(n) {
        word.write_char(c)
        word.write_char(n)
        i += 2
        continue
      }
      if c == q {
        quote = None
      }
      word.write_char(c)
    } else if c == '\\' && next == Some('\n') {
      flush_word(word, words)
      i += 2
      continue
    } else if c == '\\' && next is Some(n) {
      word.write_char(c)
      word.write_char(n)
      i += 2
      continue
    } else if c == '\'' || c == '"' {
      quote = Some(c)
      word.write_char(c)
    } else if c == '(' && next == Some('(') {
      arithmetic += 1
      word.write_string("((")
      i += 2
      continue
    } else if c == ')' && arithmetic > 0 && next == Some(')') {
      arithmetic -= 1
      word.write_string("))")
      i += 2
      continue
    } else if arithmetic == 0 &&
      (c == ';' || c == '\n' || (c == '&' && next == Some('&'))) {
      flush_word(word, words)
      if !words.is_empty() {
        segments.push(words.copy())
        words.clear()
      }
      if c == '&' {
        i += 1
      }
    } else if @whitespace.is_space(c) {
      flush_word(word, words)
    } else {
      word.write_char(c)
    }
    i += 1
  }

  flush_word(word, words)
  if !words.is_empty() {
    segments.push(words)
  }

  segments
}

///|
fn flush_word(word : StringBuilder, words : Array[String]) -> Unit {
  if !word.is_empty() {
    words.push(word.to_string())
    word.reset()
  }
}
