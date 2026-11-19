///|
let whitespace_chars : String = regex_whitespace()

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
