///|
pub async fn run(
  matches : @argparse.Matches,
  home : String,
  now_ms : Int64,
) -> Unit {
  @stdio.stdout.write(report(matches, home, now_ms))
}

///|
async fn report(
  matches : @argparse.Matches,
  home : String,
  now_ms : Int64,
) -> String {
  let window = @options.Window::parse(matches, now_ms)

  let report = @analysis.Report::new(home~)
  let records = @logfiles.jsonl_files(
    matches.values["projects"][0],
    window.since_ms,
  )

  read_sessions(records, report)
  read_events(matches.values["events"][0], window.since_ms, report)

  report.format(days=window.days, records=records.length(), limit=window.limit)
}
