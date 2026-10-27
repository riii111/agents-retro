///|
async fn read_sessions(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let session = report.start_session()
    @logfiles.each_candidate(path, @analysis.is_candidate_line, line => {
      session.read_line(line)
    })
  }
}

///|
async fn read_events(
  path : String,
  since_ms : Int64,
  report : @analysis.Report,
) -> Unit {
  if @fs.exists(path) {
    @logfiles.each_line(path, line => {
      report.read_event(@utf8.decode_lossy(line), since_ms~)
    })
  }
}
