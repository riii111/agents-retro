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
