///|
async test "chunked JSONL reader preserves long Unicode records and the final line" {
  let dir = @fs.tmpdir(prefix="permission-jsonl")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/session.jsonl"
  let long = "x".repeat((1 << 20) - 2) + "\u{2028}tail"
  @fs.write_file(path, "\{long}\n\nlast")

  let lines = []

  @logfiles.each_line(path, line => lines.push(@utf8.decode_lossy(line)))

  assert_eq(lines, [long, "", "last"])
}
