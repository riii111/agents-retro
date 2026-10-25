///|
test "permissions options do not require message report arguments" {
  let matches = command("/home/me").parse(argv=["permissions"])
  guard matches.subcommand is Some(("permissions", permissions)) else {
    fail("missing permissions subcommand")
  }
  assert_eq(permissions.values["days"], ["7"])
  assert_eq(permissions.values["limit"], ["15"])
  assert_eq(permissions.values["projects"], ["/home/me/.claude/projects"])
  assert_eq(permissions.values["events"], [
    "/home/me/.local/state/claude/permission-events.jsonl",
  ])
}
