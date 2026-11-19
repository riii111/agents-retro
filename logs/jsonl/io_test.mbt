///|
async test "chunked JSONL reader preserves long Unicode records and the final line" {
  let dir = @fs.tmpdir(prefix="permission-jsonl")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/session.jsonl"
  let long = "x".repeat((1 << 20) - 2) + "\u{2028}tail"
  @fs.write_file(path, "\{long}\n\nlast")

  let lines = []

  @jsonl.each_line(path, line => lines.push(@utf8.decode_lossy(line)))

  assert_eq(lines, [long, "", "last"])
}

///|
async test "candidate reader skips lines rejected by the pre-filter" {
  let dir = @fs.tmpdir(prefix="candidate-jsonl")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/session.jsonl"
  @fs.write_file(path, "keep 1\nskip\nkeep 2\n")

  let lines = []

  @jsonl.each_candidate(path, line => line.find(b"keep") is Some(_), line => {
    lines.push(line)
  })

  assert_eq(lines, ["keep 1", "keep 2"])
}

///|
test "stem drops the directory and the jsonl suffix" {
  assert_eq(@jsonl.stem("/a/b/s1.jsonl"), "s1")
  assert_eq(@jsonl.stem("s2.jsonl"), "s2")
  assert_eq(@jsonl.stem("/a/notes.txt"), "notes.txt")
}
