///|
let permission_whitespace : String = permission_space_chars()

///|
let permission_rule : @string.Regex = permission_regex("\\[([^\\]]+)\\]")

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
fn permission_space_chars() -> String {
  let out = StringBuilder()
  for i in 0..<=0x3000 {
    let c = i.unsafe_to_char()
    if is_space(c) {
      out.write_char(c)
    }
  }
  out.to_string()
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
      } else if word == "-u" {
        if start + 1 == words.length() {
          return ""
        }
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
fn permission_command_shape(command : String) -> String {
  let syntax = permission_shell_syntax(command)
  if permission_loop.execute(syntax) is Some(_) {
    "loop"
  } else if syntax.contains("$(") || syntax.contains("`") {
    "command substitution"
  } else if permission_assignment.execute(syntax) is Some(_) {
    "variable assignment"
  } else if permission_compound.execute(syntax) is Some(_) {
    "compound"
  } else {
    "single command"
  }
}

///|
/// Quoted arguments are not shell control syntax; double quotes still allow substitution.
fn permission_shell_syntax(command : String) -> String {
  let out = StringBuilder()
  let chars = command.iter().collect()
  let mut quote : Char? = None
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' && quote != Some('\'') {
      out.write_char(' ')
      i += 2
      continue
    }
    if quote is Some(q) {
      if c == q {
        quote = None
      } else if q == '"' {
        if c == '`' {
          out.write_char('`')
        }
        if c == '$' && chars.get(i + 1) == Some('(') {
          out.write_string("$(")
        }
      }
      out.write_char(' ')
    } else if c == '\'' || c == '"' {
      quote = Some(c)
      out.write_char(' ')
    } else {
      out.write_char(c)
    }
    i += 1
  }
  out.to_string()
}

///|
fn permission_denial_cause(reason : String) -> String {
  if reason.is_empty() {
    "unknown"
  } else if reason.has_prefix("Classifier unavailable") {
    "classifier unavailable (not a settings issue)"
  } else if reason.has_prefix("Auto mode could not evaluate") {
    "no verdict (not a settings issue)"
  } else if permission_rule.execute(reason) is Some(m) &&
    m.group(1) is Some(rule) {
    "rule: \{rule}"
  } else {
    "other"
  }
}

///|
fn permission_replace_home(path : String, home : String) -> String {
  if path == home {
    "~"
  } else if path.strip_prefix(home + "/") is Some(rest) {
    "~/\{rest}"
  } else {
    path
  }
}

///|
fn permission_path_prefix(path : String, home : String) -> String {
  if path == home {
    return "~"
  }
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
