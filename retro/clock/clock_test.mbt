///|
test "utc_timestamp formats milliseconds and floors before the epoch" {
  inspect(@clock.utc_timestamp(0L), content="1970-01-01T00:00:00")
  inspect(@clock.utc_timestamp(-1L), content="1969-12-31T23:59:59")
  inspect(
    @clock.utc_timestamp(1_709_251_199_999L),
    content="2024-02-29T23:59:59",
  )
}

///|
test "utc_date rolls over at midnight" {
  inspect(@clock.utc_date(1_709_251_199_999L), content="2024-02-29")
  inspect(@clock.utc_date(1_709_251_200_000L), content="2024-03-01")
}

///|
test "utc_millisecond is non-negative around the epoch" {
  assert_eq(@clock.utc_millisecond(1_709_251_199_123L), 123L)
  assert_eq(@clock.utc_millisecond(-1L), 999L)
}

///|
test "in_period compares the seconds of a UTC timestamp" {
  let since = "2026-10-27T10:00:00"

  assert_true(@clock.in_period("2026-10-27T10:00:00.000Z", since~))
  assert_true(@clock.in_period("2026-10-27T10:00:00Z", since~))
  assert_true(@clock.in_period("2026-10-28T00:00:00.123Z", since~))
  assert_false(@clock.in_period("2026-10-27T09:59:59.999Z", since~))
  assert_false(@clock.in_period("2026-10-01T00:00:00.000Z", since~))
}

///|
test "in_period excludes records without a usable timestamp" {
  let since = "1970-01-01T00:00:00"

  assert_false(@clock.in_period("", since~))
  assert_false(@clock.in_period("2026-10-27", since~))
}
