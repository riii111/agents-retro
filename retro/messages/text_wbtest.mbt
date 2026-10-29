///|
test "take_chars counts characters, not code units" {
  assert_eq(take_chars("😀ab", 2), "😀a")
  assert_eq(take_last_chars("ab😀", 2), "b😀")
  assert_eq(take_last_chars("ab", 5), "ab")
  assert_eq(take_last_chars("ab😀", 0), "")
  assert_eq(take_last_chars("😀😀a", 2), "😀a")
  assert_eq(take_last_chars("", 3), "")
}

///|
test "trim removes the isspace set from both ends only" {
  assert_eq(trim("\u{3000} \t\u{85}a b\u{a0}\n\u{1f}"), "a b")
  assert_eq(trim("😀 x \u{3000}😀 "), "😀 x \u{3000}😀")
  assert_eq(trim(" \u{3000}\n"), "")
  assert_eq(trim(""), "")
}
