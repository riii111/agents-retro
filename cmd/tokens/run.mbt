///|
pub async fn run(matches : @argparse.Matches, now_ms : Int64) -> Unit {
  @stdio.stdout.write(report(matches, now_ms))
}

///|
async fn report(matches : @argparse.Matches, now_ms : Int64) -> String {
  let (days, limit) = report_options(matches)

  let since_ms = now_ms - days * 86_400_000L
  let report = @analysis.Report::new()
  let claude = @logfiles.jsonl_files(matches.values["projects"][0], since_ms)
  let codex = @logfiles.jsonl_files(matches.values["sessions"][0], since_ms)

  read_claude_logs(claude, report)
  read_codex_logs(codex, report)

  report.to_json(days~, records=claude.length() + codex.length(), limit~)
}
