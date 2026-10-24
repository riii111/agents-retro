///|
test "take_chars counts characters, not code units" {
  assert_eq(take_chars("😀ab", 2), "😀a")
  assert_eq(take_last_chars("ab😀", 2), "b😀")
  assert_eq(take_last_chars("ab", 5), "ab")
}
