///|
let whitespace_chars : String = regex_whitespace()

///|
let rule : @string.Regex = regex("\\[([^\\]]+)\\]")

///|
let segments : @string.Regex = regex("&&|;|\n")

///|
let loop_pattern : @string.Regex = regex(
  "(^|[;&|(][\{whitespace_chars}]*|\n)[\{whitespace_chars}]*(for|while|until)[\{whitespace_chars}]",
)

///|
let assignment : @string.Regex = regex(
  "(^|[;&|][\{whitespace_chars}]*|\n)[\{whitespace_chars}]*[A-Za-z_][A-Za-z0-9_]*=",
)

///|
let compound : @string.Regex = regex("&&|\\|\\||;|\\||\n")

///|
fn regex(pattern : String) -> @string.Regex {
  @string.Regex(pattern) catch {
    _ => abort("invalid permission report regex")
  }
}

///|
fn regex_whitespace() -> String {
  let out = StringBuilder()
  for i in 0..<=0x3000 {
    let c = i.unsafe_to_char()
    if @whitespace.is_space(c) {
      out.write_char(c)
    }
  }

  out.to_string()
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

///|
fn command_head(command : String) -> String {
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
fn command_shape(command : String) -> String {
  let syntax = shell_syntax(command)
  if loop_pattern.execute(syntax) is Some(_) {
    "loop"
  } else if syntax.contains("$(") || syntax.contains("`") {
    "command substitution"
  } else if assignment.execute(syntax) is Some(_) {
    "variable assignment"
  } else if compound.execute(syntax) is Some(_) {
    "compound"
  } else {
    "single command"
  }
}

///|
/// Quoted arguments are not shell control syntax; double quotes still allow substitution.
fn shell_syntax(command : String) -> String {
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
fn denial_cause(reason : String) -> String {
  if reason.is_empty() {
    "unknown"
  } else if reason.has_prefix("Classifier unavailable") {
    "classifier unavailable (not a settings issue)"
  } else if reason.has_prefix("Auto mode could not evaluate") {
    "no verdict (not a settings issue)"
  } else if rule.execute(reason) is Some(m) && m.group(1) is Some(rule) {
    "rule: \{rule}"
  } else {
    "other"
  }
}

///|
fn replace_home(path : String, home : String) -> String {
  if path == home {
    "~"
  } else if path.strip_prefix(home + "/") is Some(rest) {
    "~/\{rest}"
  } else {
    path
  }
}

///|
fn path_prefix(path : String, home : String) -> String {
  if path == home {
    return "~"
  }

  if path.find("/.git/") is Some(i) {
    return replace_home(path[:i].to_owned() + "/.git", home)
  }

  if path.strip_prefix(home + "/") is Some(rest) {
    let parts : Array[StringView] = rest.split("/").take(3).collect()
    return "~/" + parts.join("/")
  }

  let parts : Array[StringView] = path.split("/").take(4).collect()
  parts.join("/")
}
