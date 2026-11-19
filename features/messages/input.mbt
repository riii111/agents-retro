///|
async fn read_logs(
  home : String,
  since_ms : Int64,
) -> Array[@analysis.RawMessage] {
  let rows = []
  for path in jsonl_files("\{home}/.claude/projects", depth=2) {
    if @logfiles.modified_before(path, since_ms) ||
      path.has_suffix("session-corrections.jsonl") {
      continue
    }

    let project = basename(dirname(path))
    let session = stem(basename(path))
    @logfiles.each_line(path, line => {
      if !@analysis.is_candidate_line(line) {
        return
      }

      if @analysis.claude_message(@utf8.decode_lossy(line), project~, session~)
        is Some(row) {
        rows.push(row)
      }
    })
  }

  for path in jsonl_files("\{home}/.codex/sessions", depth=4) {
    if @logfiles.modified_before(path, since_ms) {
      continue
    }

    let reader = @analysis.CodexSession::new(
      @analysis.take_last_chars(stem(basename(path)), 36),
    )
    @logfiles.each_line(path, line => {
      if !@analysis.is_candidate_line(line) {
        return
      }

      if reader.read_line(@utf8.decode_lossy(line)) is Some(row) {
        rows.push(row)
      }
    })
  }

  rows
}

///|
/// Matches Python glob's exact depth and exclusion of hidden entries.
async fn jsonl_files(root : String, depth~ : Int32) -> Array[String] {
  if !@fs.exists(root) {
    return []
  }

  let mut dirs = [root]
  for _ in 1..<depth {
    let next = []
    for dir in dirs {
      for name in @fs.readdir(dir, include_hidden=false) {
        let path = "\{dir}/\{name}"
        if @fs.kind(path, follow_symlink=true) is Directory {
          next.push(path)
        }
      }
    }
    dirs = next
  }

  let files = []
  for dir in dirs {
    for name in @fs.readdir(dir, include_hidden=false) {
      if name.has_suffix(".jsonl") {
        files.push("\{dir}/\{name}")
      }
    }
  }

  files
}

///|
async fn read_text(path : String) -> String {
  @utf8.decode_lossy(@fs.read_file(path).binary())
}

///|
fn basename(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
}

///|
fn dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[:i].to_owned()
    None => ""
  }
}

///|
fn stem(name : String) -> String {
  match name.strip_suffix(".jsonl") {
    Some(s) => s.to_owned()
    None => name
  }
}
