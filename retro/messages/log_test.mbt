///|
test "is_candidate_line keeps user turns and Codex session metadata" {
  for
    case in [
      ("{\"type\":\"user\",\"message\":{\"content\":\"x\"}}", true),
      ("{\"type\": \"user\"}", true),
      ("{\"type\":\"session_meta\",\"payload\":{}}", true),
      ("{\"type\":\"response_item\",\"payload\":{\"role\":\"user\"}}", true),
      ("{\"type\":\"\\u0075ser\"}", true),
      ("{\"type\":\"session\\u005fmeta\"}", true),
      ("{\"type\":\"assistant\",\"message\":{\"content\":\"the user\"}}", false),
      (
        "{\"type\":\"response_item\",\"payload\":{\"role\":\"assistant\"}}", false,
      ),
    ] {
    let (line, expected) = case

    assert_eq(
      @messages.is_candidate_line(@utf8.encode(line)),
      expected,
      msg=line,
    )
  }
}
