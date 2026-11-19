///|
test "home shortening respects complete directory boundaries" {
  for
    (path, expected) in [
      ("/home/me", "~"),
      ("/home/me/repo", "~/repo"),
      ("/home/meow/x", "/home/meow/x"),
      ("/tmp/home/me/x", "/tmp/home/me/x"),
    ] {
    assert_eq(replace_home(path, "/home/me"), expected, msg=path)
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
    assert_eq(path_prefix(path, "/home/me"), expected, msg=path)
  }
}
