///|
test "utc_isoformat matches Python's isoformat for UTC" {
  assert_eq(utc_isoformat(0L), "1970-01-01T00:00:00+00:00")
  assert_eq(utc_isoformat(1709251199123L), "2024-02-29T23:59:59.123000+00:00")
}
