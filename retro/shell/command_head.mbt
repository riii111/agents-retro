///|
let command_openers : Array[String] = [
  "if", "elif", "then", "else", "do", "while", "until", "!", "{",
]

///|
let non_commands : Array[String] = [
  "for", "select", "function", "fi", "done", "}",
]

///|
priv struct CaseScope {
  mut depth : Int32
  mut pattern_next : Bool
}

///|
pub fn command_head(command : String) -> String {
  let cases = { depth: 0, pattern_next: false, }
  for words in split_segments(command) {
    guard cases.command_start(words) is Some(start) else { continue }
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
fn CaseScope::command_start(self : CaseScope, words : Array[String]) -> Int32? {
  if words == [";;"] {
    self.pattern_next = self.depth > 0
    return None
  }

  let mut start = 0
  while true {
    if start < words.length() && words[start] == "esac" {
      if self.depth > 0 {
        self.depth -= 1
      }
      self.pattern_next = false
      return None
    }
    if self.pattern_next {
      guard pattern_end(words, start) is Some(end) else { return None }
      self.pattern_next = false
      start = end
    }
    if start >= words.length() {
      return None
    }

    let word = words[start]
    if is_assignment(word) || word == "env" || command_openers.contains(word) {
      start += 1
    } else if word == "-u" {
      start += 2
    } else if word == "case" {
      guard keyword_index(words, "in", start + 1) is Some(in_index) else {
        return None
      }
      self.depth += 1
      self.pattern_next = true
      start = in_index + 1
    } else {
      break
    }
  }

  let head = words[start]
  if head == "cd" || head.has_prefix("((") || non_commands.contains(head) {
    None
  } else {
    Some(start)
  }
}

///|
fn keyword_index(
  words : Array[String],
  keyword : String,
  from : Int32,
) -> Int32? {
  for i in from..<words.length() {
    if words[i] == keyword {
      return Some(i)
    }
  }

  None
}

///|
fn pattern_end(words : Array[String], from : Int32) -> Int32? {
  for i in from..<words.length() {
    if words[i].has_suffix(")") {
      return Some(i + 1)
    }
  }

  None
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
      } else if c == ';' && next == Some(';') {
        segments.push([";;"])
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
