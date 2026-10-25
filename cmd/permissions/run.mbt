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
  let (days, limit) = report_options(matches)

  let since_ms = now_ms - days * 86_400_000L
  let report = @analysis.Report::new(home~)
  let records = records(matches.values["projects"][0], since_ms)

  read_sessions(records, report)
  read_events(matches.values["events"][0], since_ms, report)

  report.format(days~, records=records.length(), limit~)
}
