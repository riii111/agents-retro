///|
async fn read_claude_logs(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let log = report.claude_log()
    @logfiles.each_line(path, line => {
      if @analysis.is_claude_candidate(line) {
        log.read_line(@utf8.decode_lossy(line))
      }
    })
  }
}
