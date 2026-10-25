///|
pub async fn modified_before(path : String, ms : Int64) -> Bool {
  let (sec, nsec) = @fs.mtime(path)
  sec * 1000L + (nsec / 1_000_000).to_int64() < ms
}

///|
pub async fn each_line(path : String, handle : (BytesView) -> Unit) -> Unit {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let partial = Buffer()
  while file.read_some(max_len=1 << 20) is Some(chunk) {
    let mut start = 0
    for i in 0..<chunk.length() {
      if chunk[i] != b'\n' {
        continue
      }
      if partial.is_empty() {
        handle(chunk[start:i])
      } else {
        partial.write_bytesview(chunk[start:i])
        handle(partial.to_bytes())
        partial.reset()
      }
      start = i + 1
    }
    partial.write_bytesview(chunk[start:])
  }
  if !partial.is_empty() {
    handle(partial.to_bytes())
  }
}
