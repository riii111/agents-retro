///|
pub async fn run(matches : @argparse.Matches, now_ms : Int64) -> Unit {
  @stdio.stdout.write(report(matches, now_ms))
}

///|
async fn report(matches : @argparse.Matches, now_ms : Int64) -> String {
  let window = @options.Window::parse(matches, now_ms)

  let report = @analysis.Report::new()
  let claude = @logfiles.jsonl_files(
    matches.values["projects"][0],
    window.since_ms,
  )
  let codex = @logfiles.jsonl_files(
    matches.values["sessions"][0],
    window.since_ms,
  )

  let since = @clock.utc_millis_timestamp(window.since_ms)
  read_claude_logs(claude, report, since~)
  read_codex_logs(codex, report, since~)

  report.to_json(
    days=window.days,
    records=claude.length() + codex.length(),
    limit=window.limit,
  )
}
