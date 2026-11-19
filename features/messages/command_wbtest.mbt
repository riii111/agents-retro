///|
test "message report options" {
  let matches = command().parse(argv=[
    "--days", "3", "--patterns", "patterns.json", "--out-dir", "out",
  ])

  assert_eq(matches.values["days"], ["3"])
  assert_eq(matches.values["patterns"], ["patterns.json"])
  assert_eq(matches.values["out-dir"], ["out"])
}

///|
test "message report requires patterns and out-dir" {
  for args in [[], ["--patterns", "patterns.json"], ["--out-dir", "out"]] {
    let rejected = try {
      ignore(command().parse(argv=args))
      false
    } catch {
      _ => true
    }

    assert_true(rejected)
  }
}

///|
test "message report options for weekly output and candidates are opt-in" {
  let plain = command().parse(argv=[
    "--patterns", "patterns.json", "--out-dir", "out",
  ])

  assert_true(plain.flags.get("by-week") != Some(true))
  assert_true(plain.values.get("candidates") is None)

  let matches = command().parse(argv=[
    "--patterns", "patterns.json", "--out-dir", "out", "--by-week", "--candidates",
    "candidates.json",
  ])

  assert_eq(matches.flags.get("by-week"), Some(true))
  assert_eq(matches.values.get("candidates"), Some(["candidates.json"]))
}
