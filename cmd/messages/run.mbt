///|
pub async fn run(
  matches : @argparse.Matches,
  home : String,
  now_ms : Int64,
) -> Unit {
  let days = @string.parse_int64(matches.values["days"][0])
  let patterns_path = matches.values["patterns"][0]
  let out_dir = matches.values["out-dir"][0]
  let since_ms = now_ms - days * 86_400_000L
  let by_week = matches.flags.get("by-week") == Some(true)
  let candidates_path = matches.values.get("candidates").map(v => v[0])

  let today = local_date()
  let patterns = @analysis.parse_patterns(read_text(patterns_path))

  let since = @analysis.utc_isoformat(since_ms)
  let (messages, delegated) = @analysis.collect(
    read_logs(home, since_ms),
    since~,
  )

  let candidates = match candidates_path {
    Some(path) => @analysis.parse_patterns(read_text(path))
    None => []
  }

  @fs.mkdir(out_dir, recursive=true, allow_exist=true)
  let previous = previous_metrics(out_dir, today)

  let messages_path = "\{out_dir}/\{today}-messages.tsv"
  write_lines(messages_path, messages.iter().map(@analysis.message_tsv_line))

  let hits = @analysis.match_patterns(messages, patterns)
  let examples_path = "\{out_dir}/\{today}-examples.tsv"
  write_lines(
    examples_path,
    @analysis.pattern_examples(hits)
    .iter()
    .map(e => @analysis.example_tsv_line(e.0, e.1)),
  )

  let chunks = @analysis.unmatched_chunks(messages, hits)
  let unmatched_paths = write_unmatched_chunks(out_dir, today, chunks)

  let candidate_hits = @analysis.match_patterns(messages, candidates)
  let metrics : @analysis.Metrics = {
    since,
    messages: messages.length(),
    sessions: @analysis.session_count(messages),
    delegated,
    by_role: @analysis.count_by_role(messages),
    unmatched: chunks.fold(init=0, (n, chunk) => n + chunk.length()),
    patterns: @analysis.count_patterns(hits),
    period: if by_week || candidates_path is Some(_) {
      Some(@analysis.Period::utc(days~, until_ms=now_ms))
    } else {
      None
    },
    apps: if by_week {
      @analysis.app_breakdown(messages, hits)
    } else {
      []
    },
    weeks: if by_week {
      @analysis.weekly_breakdown(messages, hits, since_ms~, until_ms=now_ms)
    } else {
      []
    },
    candidates: @analysis.count_candidates(
      candidate_hits,
      hits,
      previous,
      today~,
    ),
  }
  @fs.write_file("\{out_dir}/\{today}-metrics.json", metrics.to_json())

  println(
    @analysis.format_summary(
      metrics,
      previous,
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
