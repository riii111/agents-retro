///|
async fn read_sessions(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let session = report.start_session(id=session_id(path))
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

///|
/// A subagent log sits under `<session>/subagents/` and belongs to the session that started it.
fn session_id(path : String) -> String {
  let parts : Array[StringView] = path.split("/").collect()
  let n = parts.length()
  if n >= 3 && parts[n - 2] == "subagents" {
    parts[n - 3].to_owned()
  } else {
    @logfiles.stem(path)
  }
}
