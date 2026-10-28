///|
fn command() -> @argparse.Command {
  @argparse.Command("test", options=[days(), limit(), projects("/home/u")])
}

///|
test "window defaults to a week and 15 rows" {
  let matches = command().parse(argv=[])

  let window = Window::parse(matches, 10L * 86_400_000L)

  assert_eq(window.days, 7L)
  assert_eq(window.limit, 15)
  assert_eq(window.since_ms, 3L * 86_400_000L)
  assert_eq(matches.values["projects"][0], "/home/u/.claude/projects")
}

///|
test "window rejects negative values and keeps zero" {
  for args in [["--days", "-1"], ["--limit=-1"]] {
    let matches = command().parse(argv=args)

    let error = try {
      ignore(Window::parse(matches, 0L))
      ""
    } catch {
      err => err.to_string()
    }

    assert_true(error.contains("must be non-negative"))
  }

  let window = Window::parse(
    command().parse(argv=["--days", "0", "--limit", "0"]),
    5L,
  )

  assert_eq(window.since_ms, 5L)
  assert_eq(window.limit, 0)
}
