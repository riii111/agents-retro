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
      (
        "直して <skill>\n<name>task-worker</name>\n<path>/p/SKILL.md</path>\n---\nname: x\n# Body\n</skill>",
        "直して",
      ),
      (
        "<skill>\n<name>a</name>\n<path>/p</path>\nbody\n</skill> 続きをお願い",
        "続きをお願い",
      ),
      (
        "前 <skill>\n<name>a</name>\n<path>/p</path>\nx</skill> <skill>\n<name>b</name>\n<path>/q</path>\ny</skill> 後",
        "前 後",
      ),
      (
        "<skill>だけ書いた文章</skill>", "<skill>だけ書いた文章</skill>",
      ),
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

///|
test "collect keeps a request around an expanded skill and does not drop long ones" {
  let skill = "<skill>\n<name>n</name>\n<path>/p</path>\nbody\n</skill>"
  let long = "あ".repeat(5000)
  let (messages, _) = collect(
    [
      raw("2026-10-20T01:00:00.000Z", "\{skill} 先に依頼", session="a"),
      raw("2026-10-20T02:00:00.000Z", "後ろに依頼 \{skill}", session="b"),
      raw("2026-10-20T03:00:00.000Z", skill, session="c"),
      raw("2026-10-20T04:00:00.000Z", "\{long} 依頼", session="d"),
    ],
    since="2026-10-17T00:00:00.000000+00:00",
  )

  assert_eq(messages.map(m => m.text.length()), [4, 5, 5003])
  assert_eq(messages[0].text, "先に依頼")
  assert_eq(messages[1].text, "後ろに依頼")
}
