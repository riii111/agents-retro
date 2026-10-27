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

///|
pub async fn jsonl_files(root : String, since_ms : Int64) -> Array[String] {
  let files = []
  if !@fs.exists(root) || @fs.kind(root, follow_symlink=true) != Directory {
    return files
  }

  walk(root, since_ms, files)

  files
}

///|
async fn walk(root : String, since_ms : Int64, files : Array[String]) -> Unit {
  let names = @fs.readdir(root, include_hidden=true)

  for name in names {
    let path = "\{root}/\{name}"
    if !name.has_suffix(".jsonl") {
      continue
    }

    let kind = @fs.kind(path, follow_symlink=true) catch { _ => continue }
    if kind is Regular && !modified_before(path, since_ms) {
      files.push(path)
    }
  }

  for name in names {
    let path = "\{root}/\{name}"
    if @fs.kind(path, follow_symlink=false) is Directory {
      walk(path, since_ms, files)
    }
  }
}
