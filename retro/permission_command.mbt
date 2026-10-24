///|
/// Python's Unicode \s includes four control separators absent from Unicode White_Space.
let permission_whitespace : String = "\t\n\u{0b}\u{0c}\r \u{1c}-\u{1f}\u{85}\u{a0}\u{1680}\u{2000}-\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}"

///|
let permission_segments : @string.Regex = permission_regex("&&|;|\n")

///|
let permission_loop : @string.Regex = permission_regex(
  "(^|[;&|(][\{permission_whitespace}]*|\n)[\{permission_whitespace}]*(for|while|until)[\{permission_whitespace}]",
)

///|
let permission_assignment : @string.Regex = permission_regex(
  "(^|[;&|][\{permission_whitespace}]*|\n)[\{permission_whitespace}]*[A-Za-z_][A-Za-z0-9_]*=",
)

///|
let permission_compound : @string.Regex = permission_regex("&&|\\|\\||;|\\||\n")

///|
fn permission_regex(pattern : String) -> @string.Regex {
  @string.Regex(pattern) catch {
    _ => abort("invalid permission report regex")
  }
}

///|
fn permission_words(text : StringView) -> Array[String] {
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
  words
}

///|
fn permission_command_head(command : String) -> String {
  for segment in permission_segments.split(command) {
    let words = permission_words(segment)
    let mut start = 0
    while start < words.length() {
      let word = words[start]
      if (word.contains("=") && !word.has_prefix("-")) || word == "env" {
        start += 1
      } else if word == "-u" && start + 1 < words.length() {
        start += 2
      } else {
        break
      }
    }
    if start == words.length() || words[start] == "cd" {
      continue
    }
    let head = words[start]
    if ["git", "gh", "bun", "bunx", "npm", "npx", "cargo", "go", "nix", "uv"].contains(
        head,
      ) {
      let rest_start = if words.get(start + 1) == Some("-C") &&
        start + 3 < words.length() {
        start + 3
      } else {
        start + 1
      }
      for i in rest_start..<words.length() {
        if !words[i].has_prefix("-") {
          return "\{head} \{words[i]}"
        }
      }
    }
    return head
  }
  ""
}

///|
fn permission_command_shape(command : String) -> String {
  if permission_loop.execute(command) is Some(_) {
    "loop"
  } else if command.contains("$(") || command.contains("`") {
    "command substitution"
  } else if permission_assignment.execute(command) is Some(_) {
    "variable assignment"
  } else if permission_compound.execute(command) is Some(_) {
    "compound"
  } else {
    "single command"
  }
}

///|
fn permission_denial_cause(reason : String) -> String {
  if reason.is_empty() {
    "unknown"
  } else if reason.has_prefix("Classifier unavailable") {
    "classifier unavailable (not a settings issue)"
  } else if reason.has_prefix("Auto mode could not evaluate") {
    "no verdict (not a settings issue)"
  } else if permission_regex("\\[([^\\]]+)\\]").execute(reason) is Some(m) &&
    m.group(1) is Some(rule) {
    "rule: \{rule}"
  } else {
    "other"
  }
}

///|
fn permission_replace_home(path : String, home : String) -> String {
  match path.find(home) {
    Some(i) => path[:i].to_owned() + "~" + path[i + home.length():].to_owned()
    None => path
  }
}

///|
fn permission_path_prefix(path : String, home : String) -> String {
  if path.find("/.git/") is Some(i) {
    return permission_replace_home(path[:i].to_owned() + "/.git", home)
  }
  if path.strip_prefix(home + "/") is Some(rest) {
    let parts : Array[StringView] = rest.split("/").take(3).collect()
    return "~/" + parts.join("/")
  }
  let parts : Array[StringView] = path.split("/").take(4).collect()
  parts.join("/")
}
