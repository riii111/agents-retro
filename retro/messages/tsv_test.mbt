///|
test "message_tsv_line" {
  assert_eq(
    @messages.message_tsv_line(msg(7, "  a\n\tb\u{3000}c  ", session="s")),
    "7\t2026-10-20T01:23\tcodex\tuser\ts\t/w\ta b c",
  )
}

///|
test "previews keep short text whole and cut long text to head and tail" {
  assert_eq(
    @messages.example_tsv_line("review", msg(7, " a\nb ", session="s")),
    "review\t7\ts\ta b",
  )

  let head = "あ".repeat(140)
  let tail = "い".repeat(60)
  let long = msg(8, head + "う".repeat(100) + tail, session="s")

  assert_eq(
    @messages.unmatched_tsv_line(long),
    "8\t\{head} …[300字]… \{tail}",
  )

  let limit = msg(9, "え".repeat(200), session="s")

  assert_eq(@messages.unmatched_tsv_line(limit), "9\t\{"え".repeat(200)}")
}
