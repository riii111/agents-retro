///|
test "message report options and required paths" {
  let messages = @argparse.Command("agents-retro", options=options()).parse(argv=[
    "--days", "3", "--patterns", "patterns.json", "--out-dir", "out",
  ])
  assert_eq(paths(messages), ("patterns.json", "out"))
  assert_eq(messages.values["days"], ["3"])
  for args in [[], ["--patterns", "patterns.json"], ["--out-dir", "out"]] {
    let rejected = try {
      ignore(
        paths(
          @argparse.Command("agents-retro", options=options()).parse(argv=args),
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
