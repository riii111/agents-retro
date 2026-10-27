///|
async fn read_claude_logs(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let log = report.claude_log(session=stem(path))
    @logfiles.each_line(path, line => {
      if @analysis.is_claude_candidate(line) {
        log.read_line(@utf8.decode_lossy(line))
      }
    })
  }
}

///|
async fn read_codex_logs(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let log = report.codex_log(session=stem(path))
    @logfiles.each_line(path, line => {
      if @analysis.is_codex_candidate(line) {
        log.read_line(@utf8.decode_lossy(line))
      }
    })
  }
}

///|
async fn installed_skills(root : String) -> Array[String] {
  let names = []
  if !@fs.exists(root) || @fs.kind(root, follow_symlink=true) != Directory {
    return names
  }

  for name in @fs.readdir(root) {
    if @fs.exists("\{root}/\{name}/SKILL.md") {
      names.push(name)
    }
  }
  names.sort_by((a, b) => a.lexical_compare(b))

  names
}

///|
fn stem(path : String) -> String {
  let name = match path.rev_find("/") {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }

  match name.strip_suffix(".jsonl") {
    Some(s) => s.to_owned()
    None => name
  }
}
