///|
fn raw(
  ts : String,
  text : String,
  session~ : String = "s",
) -> @retro.RawMessage {
  { ts, app: "claude", role: "main", session, cwd: "", raw: text, }
}

///|
test "collect filters, dedupes and numbers in time order" {
  let (messages, delegated) = @retro.collect(
    [
      raw("2026-10-20T02:00:00.000Z", "second"),
      raw("2026-10-20T01:30Z", "middle"),
      raw("2026-10-20T01:00:00.000Z", "first"),
      raw("2026-10-20T01:00:00.500Z", "first", session="fork"),
      raw("2026-10-10T00:00:00.000Z", "too old"),
      raw("2026-10-20T03:00:00.000Z", "<codex_delegation>do it"),
      raw("2026-10-20T03:00:00.000Z", "<system-reminder>"),
    ],
    since="2026-10-17T00:00:00.000000+00:00",
  )
  assert_eq(messages.map(m => (m.id, m.text)), [
    (1, "first"),
    (2, "middle"),
    (3, "second"),
  ])
  assert_eq(delegated, 1)
}
