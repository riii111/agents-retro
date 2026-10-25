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
