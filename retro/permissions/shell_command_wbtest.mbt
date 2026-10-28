///|
test "permission command normalization and shape precedence" {
  for
    (command, head, shape) in [
      (
        "cd /tmp && env -u TOKEN A=1 git -C /repo --no-pager status", "git status",
        "compound",
      ),
      ("A=1 npm run check", "npm run", "variable assignment"),
      ("for x in a; do echo $(date); done", "echo", "loop"),
      ("echo `date` | cat", "echo", "command substitution"),
      ("\u{3000}uv\u{3000}run main.py", "uv run", "single command"),
      ("cd /tmp; cd /repo", "", "compound"),
      ("git -C /repo", "git", "single command"),
      ("env -u", "", "single command"),
      ("env -u; git status", "git status", "compound"),
      ("env -u TOKEN", "", "single command"),
      ("git -C /repo -C /other status", "git status", "single command"),
      ("echo '$(date); while true'", "echo", "single command"),
      ("echo \"$(date)\"", "echo", "command substitution"),
      ("echo \"for x in a; do echo x; done\"", "echo", "single command"),
      ("x=1\necho ok", "echo", "variable assignment"),
      ("echo '(while x)'", "echo", "single command"),
    ] {
    assert_eq(@shell.command_head(command), head, msg=command)
    assert_eq(command_shape(command), shape, msg=command)
  }
}

///|
test "permission regex whitespace agrees with text whitespace" {
  let whitespace = regex("^[\{whitespace_chars}]$")
  for i in 0..<=0x3001 {
    let c = i.unsafe_to_char()
    assert_eq(
      whitespace.execute(c.to_string()) is Some(_),
      @whitespace.is_space(c),
      msg=i.to_string(),
    )
  }

  assert_false(whitespace.execute("\u{feff}") is Some(_))
}
