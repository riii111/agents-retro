///|
test "top keeps the largest items and the input order of ties" {
  let items = [("a", 1L), ("b", 3L), ("c", 3L), ("d", 2L)]

  let json = @jsonreport.top(items, 3, item => item.1, item => {
    Json::string(item.0)
  })

  assert_eq(json.stringify(), "[\"b\",\"c\",\"d\"]")
}

///|
test "top with a zero limit is empty" {
  let json = @jsonreport.top([1L], 0, n => n, n => @jsonreport.number(n))

  assert_eq(json.stringify(), "[]")
}

///|
test "object keeps field order and lets a later field replace an earlier one" {
  let json = @jsonreport.object([
    ("b", @jsonreport.number(1L)),
    ("a", @jsonreport.number(2L)),
    ("b", @jsonreport.number(3L)),
  ])

  assert_eq(json.stringify(), "{\"b\":3,\"a\":2}")
}
