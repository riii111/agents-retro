///|
let segments : @string.Regex = @string.Regex("&&|;|\n") catch {
  _ => abort("invalid shell segment regex")
}

///|
pub fn command_head(command : String) -> String {
  for segment in segments.split(command) {
    let words = words(segment)
    let mut start = 0
    while start < words.length() {
      let word = words[start]
      if (word.contains("=") && !word.has_prefix("-")) || word == "env" {
        start += 1
      } else if word == "-u" {
        start += 2
      } else {
        break
      }
    }

    if start >= words.length() || words[start] == "cd" {
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
fn words(text : StringView) -> Array[String] {
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

  words
}
