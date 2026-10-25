///|
test "permission command normalization and shape precedence" {
  for
    (command, head, shape) in [
      (
        "cd /tmp && env -u TOKEN A=1 git -C /repo --no-pager status", "git status",
        "compound",
      ),
      ("A=1 npm run check", "npm run", "variable assignment"),
      ("for x in a; do echo $(date); done", "for", "loop"),
      ("echo `date` | cat", "echo", "command substitution"),
      ("\u{3000}uv\u{3000}run main.py", "uv run", "single command"),
      ("cd /tmp; cd /repo", "", "compound"),
      ("git -C /repo", "git", "single command"),
      ("env -u", "", "single command"),
      ("env -u TOKEN", "", "single command"),
      ("git -C /repo -C /other status", "git status", "single command"),
      ("echo '$(date); while true'", "echo", "single command"),
      ("echo \"$(date)\"", "echo", "command substitution"),
      ("echo \"for x in a; do echo x; done\"", "echo", "single command"),
      ("x=1\necho ok", "echo", "variable assignment"),
      ("echo '(while x)'", "echo", "single command"),
    ] {
    assert_eq(permission_command_head(command), head, msg=command)
    assert_eq(permission_command_shape(command), shape, msg=command)
  }
}

///|
test "permission hook timestamps and invalid dates" {
  for
    text in [
      "1970-01-01T00:00:00+0000", "1970-01-01T09:00:00+0900", "1969-12-31T19:00:00-0500",
    ] {
    assert_eq(permission_time_ms(text), Some(0L), msg=text)
  }
  assert_eq(permission_time_ms("2000-02-29T00:00:00+0000"), Some(951782400000L))
  for
    text in [
      "1900-02-29T00:00:00+0000", "2026-02-30T00:00:00+0000", "0000-01-01T00:00:00+0000",
      "2026-00-01T00:00:00+0000", "2026-01-00T00:00:00+0000", "2026-01-01T24:00:00+0000",
      "2026-01-01T00:00:60+0000", "2026-01-01T00:00:00+2400", "2026-01-01T00:00:00+0060",
      "2026-1-01T00:00:00+0000", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00+00:00",
      "2026-01-01T00:00:00+000000.1",
    ] {
    assert_eq(permission_time_ms(text), None, msg=text)
  }
}

///|
test "home shortening respects complete directory boundaries" {
  for
    (path, expected) in [
      ("/home/me", "~"),
      ("/home/me/repo", "~/repo"),
      ("/home/meow/x", "/home/meow/x"),
      ("/tmp/home/me/x", "/tmp/home/me/x"),
    ] {
    assert_eq(permission_replace_home(path, "/home/me"), expected, msg=path)
  }
  for
    (path, expected) in [
      ("/home/me", "~"),
      ("/home/me/repo/.git/config", "~/repo/.git"),
      ("/home/meow/repo/.git/config", "/home/meow/repo/.git"),
      ("/tmp/home/me/repo/.git/config", "/tmp/home/me/repo/.git"),
      ("/home/me/.cache/tool/a/b", "~/.cache/tool/a"),
      ("/var/lib/tool/cache/file", "/var/lib/tool"),
    ] {
    assert_eq(permission_path_prefix(path, "/home/me"), expected, msg=path)
  }
}

///|
test "permission regex whitespace agrees with text whitespace" {
  let whitespace = permission_regex("^[\{permission_whitespace}]$")
  for i in 0..<=0x3001 {
    let c = i.unsafe_to_char()
    assert_eq(
      whitespace.execute(c.to_string()) is Some(_),
      is_space(c),
      msg=i.to_string(),
    )
  }
  assert_false(whitespace.execute("\u{feff}") is Some(_))
}
