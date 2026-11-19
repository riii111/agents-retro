///|
async fn read_claude_logs(
  paths : Array[String],
  report : @analysis.Report,
  since~ : String,
) -> Unit {
  for path in paths {
    let log = report.claude_log(session=@logfiles.stem(path), since~)
    @logfiles.each_candidate(path, @analysis.is_claude_candidate, line => {
      log.read_line(line)
    })
  }
}

///|
async fn read_codex_logs(
  paths : Array[String],
  report : @analysis.Report,
  since~ : String,
) -> Unit {
  for path in paths {
    let log = report.codex_log(session=@logfiles.stem(path), since~)
    @logfiles.each_candidate(path, @analysis.is_codex_candidate, line => {
      log.read_line(line)
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
