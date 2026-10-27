///|
let segments : @string.Regex = @string.Regex("&&|;|\n") catch {
  _ => abort("invalid shell segment regex")
}

///|
/// Reserved words that precede the command they introduce.
let command_openers : Array[String] = [
  "if", "elif", "then", "else", "do", "while", "until", "!", "{",
]

///|
/// Reserved words whose segment holds no command to execute.
let non_commands : Array[String] = [
  "for", "select", "case", "function", "fi", "done", "esac", "}",
]

///|
pub fn command_head(command : String) -> String {
  for segment in segments.split(command) {
    let words = words(segment)
    let mut start = 0
    while start < words.length() {
      let word = words[start]
      if is_assignment(word) || word == "env" || command_openers.contains(word) {
        start += 1
      } else if word == "-u" {
        start += 2
      } else {
        break
      }
    }

    if start >= words.length() ||
      words[start] == "cd" ||
      non_commands.contains(words[start]) {
      continue
    }

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
/// Whitespace inside quotes does not split a word; quotes stay in the word.
fn words(text : StringView) -> Array[String] {
  let words = []
  let word = StringBuilder()
  let mut quote : Char? = None
  for c in text {
    if quote is Some(q) {
      if c == q {
        quote = None
      }
      word.write_char(c)
    } else if c == '\'' || c == '"' {
      quote = Some(c)
      word.write_char(c)
    } else if @whitespace.is_space(c) {
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

  words
}
