///|
fn permission_test_events(
  report : @retro.PermissionReport,
  source : String,
  since_ms~ : Int64 = 0L,
) -> Unit {
  for line in source.split("\n") {
    report.read_event(line, since_ms~)
  }
}

///|
test "complete permission report keeps causes sessions sandbox evidence and ordering" {
  let report = @retro.PermissionReport::new(home="/home/me")
  permission_test_events(
    report,
    (
      #|{"time":"1970-01-01T09:00:00+0900","event":"PermissionRequest","tool":"Bash","command":"git status","session":"one","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T09:00:00+0900","event":"PermissionRequest","tool":"Bash","command":"git status","session":"one","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T09:00:00+0900","event":"PermissionRequest","tool":"Bash","command":"cd /repo && git status","unsandboxed":true,"session":"two","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionRequest","tool":"Read","session":"three","cwd":"/home/meow/x"}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionDenied","tool":"Bash","command":"git push","reason":"blocked [external]","session":"one","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionDenied","tool":"Bash","command":"git push","reason":"blocked [external]","session":"two","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionDenied","tool":"Bash","command":"git push","reason":"Classifier unavailable","session":"one","cwd":"/home/me/repo"}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionDenied","tool":"Bash","command":"cargo test","reason":"Auto mode could not evaluate this action","session":"one","cwd":"/home/me/repo"}
    ),
  )
  let session = report.start_session()
  session.read_line(
    (
      #|{"type":"assistant","message":{"content":[{"type":"tool_use","id":"shared","name":"Bash","input":{"command":"cargo test"}},{"type":"tool_result","tool_use_id":"shared","content":[{"text":"open /home/me/repo/.git/config: Operation not permitted\n'/home/me/.cache/tool/a/b': Read-only file system\ndeny network-outbound example.com:443"},null]}]}}
    ),
  )
  session.read_line(
    (
      #|{"message":{"content":[{"type":"tool_use","id":"outside","name":"Bash","input":{"command":"npm install","dangerouslyDisableSandbox":true}},{"type":"tool_result","tool_use_id":"outside","content":"open /secret: Operation not permitted\ndeny network-outbound ignored.example"}]}}
    ),
  )
  report
  .start_session()
  .read_line(
    (
      #|{"message":{"content":[{"type":"tool_result","tool_use_id":"shared","content":"open /wrong: Operation not permitted"}]}}
    ),
  )
  let expected =
    #|# Sandbox report: last 7 days, 2 session records
    #|
    #|## Permission prompts by command shape
    #|    2  single command
    #|    1  compound (rerun outside the sandbox)
    #|    1  tool: Read
    #|
    #|## Permission prompts by command
    #|    3  git status  (2 sessions)
    #|    1  tool: Read  (1 sessions)
    #|
    #|## Permission prompts by working directory
    #|    3  ~/repo
    #|    1  /home/meow/x
    #|
    #|## Auto mode denials by command shape
    #|    4  single command
    #|
    #|## Auto mode denials by cause and command
    #|    2  rule: external | git push  (2 sessions)
    #|    1  classifier unavailable (not a settings issue) | git push  (1 sessions)
    #|    1  no verdict (not a settings issue) | cargo test  (1 sessions)
    #|
    #|## Auto mode denials by working directory
    #|    4  ~/repo
    #|
    #|## Auto mode denials by cause
    #|    2  rule: external
    #|    1  classifier unavailable (not a settings issue)
    #|    1  no verdict (not a settings issue)
    #|
    #|## Commands rerun outside the sandbox
    #|    1  npm install
    #|
    #|## Sandboxed commands that failed to write
    #|    1  cargo test
    #|
    #|## Paths the sandbox refused to write
    #|    1  ~/repo/.git
    #|    1  ~/.cache/tool/a
    #|
    #|## Hosts the sandbox refused
    #|    1  example.com
  assert_eq(report.format(days=7L, records=2, limit=15), expected + "\n\n")
}

///|
test "empty permission report" {
  let expected =
    #|# Sandbox report: last 7 days, 0 session records
    #|
    #|## Permission prompts by command shape
    #|(none)
    #|
    #|## Permission prompts by command
    #|(none)
    #|
    #|## Permission prompts by working directory
    #|(none)
    #|
    #|## Auto mode denials by command shape
    #|(none)
    #|
    #|## Auto mode denials by cause and command
    #|(none)
    #|
    #|## Auto mode denials by working directory
    #|(none)
    #|
    #|## Auto mode denials by cause
    #|(none)
    #|
    #|## Commands rerun outside the sandbox
    #|(none)
    #|
    #|## Sandboxed commands that failed to write
    #|(none)
    #|
    #|## Paths the sandbox refused to write
    #|(none)
    #|
    #|## Hosts the sandbox refused
    #|(none)
  assert_eq(
    @retro.PermissionReport::new(home="/home/me").format(
      days=7L,
      records=0,
      limit=15,
    ),
    expected + "\n\n",
  )
}

///|
test "permission cutoff malformed lines and limited stable ordering" {
  let report = @retro.PermissionReport::new(home="/home/me")
  permission_test_events(
    report,
    (
      #|{"time":"1970-01-01T08:59:59+0900","event":"PermissionRequest","tool":"Bash","command":"excluded"}
      #|not json
      #|{"time":"invalid","event":"PermissionRequest"}
      #|{"time":"1970-01-01T09:00:00+0900","event":"Other"}
      #|{"time":"1970-01-01T09:00:00+0900","event":"PermissionRequest","tool":"Bash","command":"zeta","session":"one"}
      #|{"time":"1969-12-31T19:00:01-0500","event":"PermissionRequest","tool":"Bash","command":"alpha","session":"two"}
      #|{"time":"1970-01-01T00:00:01+0000","event":"PermissionRequest","tool":"Bash","command":"zeta","session":"two"}
      #|{"time":"1970-01-01T00:00:01+0000","event":"PermissionRequest","tool":"Bash","command":"alpha","session":"two"}
    ),
  )
  let limited = report.format(days=7L, records=0, limit=1)
  assert_true(
    limited.contains(
      "## Permission prompts by command\n    2  zeta  (2 sessions)\n\n",
    ),
  )
  assert_false(limited.contains("alpha"))
  let all = report.format(days=7L, records=0, limit=15)
  assert_true(
    all.contains("    2  zeta  (2 sessions)\n    2  alpha  (1 sessions)\n"),
  )
  assert_false(all.contains("excluded"))
  let limit = 0
  assert_true(
    report
    .format(days=7L, records=0, limit~)
    .contains("## Permission prompts by command\n\n"),
  )
}

///|
test "events with missing and null tool names use unknown" {
  let report = @retro.PermissionReport::new(home="/home/me")
  permission_test_events(
    report,
    (
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionRequest","session":"one"}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionRequest","session":"two","tool":null}
      #|{"time":"1970-01-01T00:00:00+0000","event":"PermissionRequest","session":"one","tool":"Read"}
    ),
  )
  let output = report.format(days=7L, records=0, limit=15)
  assert_true(output.contains("    2  tool: unknown  (2 sessions)\n"))
  assert_true(output.contains("    1  tool: Read  (1 sessions)\n"))
  assert_false(output.contains("tool: None"))
}

///|
test "raw Unicode line separators remain inside JSON event and session records" {
  let report = @retro.PermissionReport::new(home="/home/me")
  report.read_event(
    "{\"time\":\"1970-01-01T00:00:00+0000\",\"event\":\"PermissionRequest\",\"tool\":\"Bash\",\"command\":\"git\u{2028}status\",\"cwd\":\"/home/me/repo\u{2028}name\"}",
    since_ms=0L,
  )
  report
  .start_session()
  .read_line(
    "{\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"unicode\",\"name\":\"Bash\",\"input\":{\"command\":\"git\u{2028}status\",\"dangerouslyDisableSandbox\":true}}]}}",
  )
  let output = report.format(days=7L, records=1, limit=15)
  assert_true(output.contains("    1  git status  (1 sessions)"))
  assert_true(output.contains("    1  ~/repo\u{2028}name\n"))
  assert_true(
    output.contains(
      "## Commands rerun outside the sandbox\n    1  git status\n",
    ),
  )
}
