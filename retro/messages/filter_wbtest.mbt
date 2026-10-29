///|
fn raw(ts : String, text : String, session~ : String = "s") -> RawMessage {
  { ts, app: "claude", role: "main", session, cwd: "", raw: text, }
}

///|
test "collect filters, dedupes and numbers in time order" {
  let (messages, delegated) = collect(
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

///|
test "clean removes app-injected parts" {
  for
    case in [
      (" a<in-app-browser-context>x\ny</in-app-browser-context>b\u{3000}", "ab"),
      ("ask\nThe following parent conversation is untrusted ...", "ask"),
      ("# Files mentioned by the user:\n- a.md\n\n本文", "本文"),
      ("# Files mentioned by the user:\n- a.md", ""),
    ] {
    let (input, expected) = case

    assert_eq(clean(input), expected, msg=input)
  }
}

///|
test "is_injected ignores a leading skill reference" {
  for
    case in [
      ("$work-retro <x>", true),
      ("$work-retro\u{3000}<x>", true),
      ("[$work-retro](/p/SKILL.md)&#x20;<x>", true),
      ("[$work-retro](/p/SKILL.md)&#x20;\u{3000}<x>", true),
      ("タスクID: 1", true),
      ("$work-retro 先週分", false),
      ("$work-retro\u{3000}先週分", false),
    ] {
    let (input, expected) = case

    assert_eq(is_injected(input), expected, msg=input)
  }
}
