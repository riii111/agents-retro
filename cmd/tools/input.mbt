///|
async fn read_claude_logs(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let log = report.claude_log(session=@logfiles.stem(path))
    @logfiles.each_candidate(path, @analysis.is_claude_candidate, line => {
      log.read_line(line)
    })
  }
}
