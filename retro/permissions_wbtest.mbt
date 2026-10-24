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
      ("git -C /repo", "git /repo", "single command"),
      ("env -u", "-u", "single command"),
      ("x=1\necho ok", "echo", "variable assignment"),
      ("echo '(while x)'", "echo", "loop"),
    ] {
    assert_eq(permission_command_head(command), head, msg=command)
    assert_eq(permission_command_shape(command), shape, msg=command)
  }
}

///|
test "permission timestamp offsets and invalid dates" {
  for
    text in [
      "1970-01-01T00:00:00Z", "1970-01-01T09:00:00+0900", "1969-12-31T19:00:00-05:00",
      "1970-1-1T0:0:0+000000.000000", "1970-01-01T00:00:01+00:00:01",
    ] {
    assert_eq(permission_time_us(text), Some(0L), msg=text)
  }
  assert_eq(permission_time_us("2000-02-29T00:00:00Z"), Some(951782400000000L))
  assert_eq(permission_time_us("1970-01-01T00:00:00+000000.000001"), Some(-1L))
  for
    text in [
      "1900-02-29T00:00:00Z", "2026-02-30T00:00:00Z", "2026-00-01T00:00:00Z", "2026-01-00T00:00:00Z",
      "2026-01-01T24:00:00Z", "2026-01-01T00:00:60Z", "2026-01-01T00:00:00", "2026-01-01T00:00:00.000Z",
      "2026-01-01T00:00:00+24:00", "2026-01-01T00:00:00+0060", "2026-01-01T00:00:00+00:0000",
      "2026-01-01T00:00:00+0000:00",
    ] {
    assert_eq(permission_time_us(text), None, msg=text)
  }
}

///|
test "permission event cutoff preserves causes sessions and tie order" {
  let report = PermissionReport::new(home="/home/me")
  report.scan_events(
    (
      #|{"time":"1970-01-01T00:00:00Z","event":"PermissionDenied","tool":"Bash","command":"git status","reason":"Classifier unavailable: outage","session":"one","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T00:00:00+000000.000001","event":"PermissionDenied","tool":"Bash","command":"excluded"}
      #|{"time":"1970-01-01T00:00:00-000000.000001","event":"PermissionDenied","tool":"Bash","command":"git status","reason":"blocked [external]","session":"one"}
      #|{"time":"1970-01-01T00:00:00Z","event":"PermissionDenied","tool":"Bash","command":"git status","reason":"blocked [external]","session":"two"}
      #|not json
      #|{"time":"invalid","event":"PermissionRequest"}
      #|{"time":"1970-01-01T00:00:00Z","event":"Other"}
    ),
    since_ms=0L,
  )
  assert_eq(report.commands[1].order, [
    "classifier unavailable (not a settings issue) | git status", "rule: external | git status",
  ])
  assert_eq(report.sessions[1]["rule: external | git status"].length(), 2)
  assert_eq(report.places[1].counts["~/repo"], 1)
  let out = StringBuilder()
  report.causes.section(out, "causes", 1)
  assert_eq(out.to_string(), "## causes\n    2  rule: external\n\n")
  let ties = PermissionCounter::new()
  ties.add("z")
  ties.add("a")
  let out = StringBuilder()
  ties.section(out, "ties", 1)
  assert_eq(out.to_string(), "## ties\n    1  z\n\n")
}

///|
test "permission session calls stay within their file and unsandboxed outputs stay excluded" {
  let report = PermissionReport::new(home="/home/me")
  report.scan_session(
    (
      #|{"message":{"content":[{"type":"tool_use","id":"same","name":"Bash","input":{"command":"env A=1 cargo test"}},{"type":"tool_result","tool_use_id":"same","content":[{"text":"open /home/me/repo/.git/config: Operation not permitted\ndeny network-outbound example.com:443"},null]}]}}
      #|{"message":{"content":[{"type":"tool_use","id":"outside","name":"Bash","input":{"command":"npm install","dangerouslyDisableSandbox":true}},{"type":"tool_result","tool_use_id":"outside","content":"open /secret: Operation not permitted\ndeny network-outbound ignored.example"}]}}
    ),
  )
  report.scan_session(
    (
      #|{"message":{"content":[{"type":"tool_result","tool_use_id":"same","content":"open /wrong: Operation not permitted"}]}}
    ),
  )
  assert_eq(report.failed.counts["cargo test"], 1)
  assert_eq(report.writes.order, ["~/repo/.git"])
  assert_eq(report.hosts.order, ["example.com"])
  assert_eq(report.reruns.order, ["npm install"])
}
