///|
test "permission candidates retain tool records and escaped types" {
  for
    line in [
      b"{\"message\":{\"content\":[{\"type\":\"tool_use\"}]}}", b"{\"message\":{\"content\":[{\"type\":\"tool_result\"}]}}",
      b"{\"message\":{\"content\":[{\"type\":\"tool\\u005fuse\"}]}}", b"{\"message\":{\"content\":[{\"type\":\"\\u0074ool_result\"}]}}",
    ] {
    assert_true(@permissions.is_candidate_line(line))
  }

  for
    line in [
      b"{\"type\":\"user\",\"message\":{\"content\":\"owner message\"}}", b"{\"type\":\"assistant\",\"message\":{\"content\":\"ordinary reply\"}}",
      b"{\"type\":\"progress\"}",
    ] {
    assert_false(@permissions.is_candidate_line(line))
  }
}
