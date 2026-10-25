///|
pub async fn run(
  matches : @argparse.Matches,
  home : String,
  now_ms : Int64,
) -> Unit {
  let days = @string.parse_int64(matches.values["days"][0])
  let (patterns_path, out_dir) = paths(matches)
  let since_ms = now_ms - days * 86_400_000L

  let today = local_date()
  let patterns = @analysis.parse_patterns(read_text(patterns_path))

  let since = @analysis.utc_isoformat(since_ms)
  let (messages, delegated) = @analysis.collect(
    read_logs(home, since_ms),
    since~,
  )

  @fs.mkdir(out_dir, recursive=true, allow_exist=true)

  let messages_path = "\{out_dir}/\{today}-messages.tsv"
  write_lines(messages_path, messages.map(@analysis.message_tsv_line))

  let hits = @analysis.match_patterns(messages, patterns)
  let examples_path = "\{out_dir}/\{today}-examples.tsv"
  write_lines(
    examples_path,
    @analysis.pattern_examples(hits).map(e => {
      @analysis.example_tsv_line(e.0, e.1)
    }),
  )

  let chunks = @analysis.unmatched_chunks(messages, hits)
  let unmatched_paths = write_unmatched_chunks(out_dir, today, chunks)

  let metrics : @analysis.Metrics = {
    since,
    messages: messages.length(),
    sessions: @analysis.session_count(messages),
    delegated,
    by_role: @analysis.count_by_role(messages),
    unmatched: chunks.fold(init=0, (n, chunk) => n + chunk.length()),
    patterns: @analysis.count_patterns(hits),
  }
  @fs.write_file("\{out_dir}/\{today}-metrics.json", metrics.to_json())

  println(
    @analysis.format_summary(
      metrics,
      previous_metrics(out_dir, today),
      examples_path~,
      unmatched_paths~,
      messages_path~,
    ),
  )
}

///|
/// The standard library has no time zone support, so the OS supplies Python's `date.today()` value.
async fn local_date() -> String {
  let (status, out) = @process.collect_stdout("date", ["+%Y-%m-%d"])
  guard status == 0 else { fail("date exited with status \{status}") }

  out.text().trim().to_owned()
}
