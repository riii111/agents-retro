///|
pub fn options() -> Array[@argparse.OptionArg] {
  [
    OptionArg("days", long="days", default_values=["7"]),
    OptionArg(
      "patterns",
      long="patterns",
      about="JSON object of category name to regex; required for message reports",
    ),
    OptionArg("out-dir", long="out-dir", about="Required for message reports"),
  ]
}

///|
fn paths(matches : @argparse.Matches) -> (String, String) raise {
  guard matches.values.get("patterns") is Some([patterns, ..]) else {
    fail("--patterns is required for message reports")
  }
  guard matches.values.get("out-dir") is Some([out_dir, ..]) else {
    fail("--out-dir is required for message reports")
  }
  (patterns, out_dir)
}

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
async fn read_logs(
  home : String,
  since_ms : Int64,
) -> Array[@analysis.RawMessage] {
  let rows = []
  for path in jsonl_files("\{home}/.claude/projects", depth=2) {
    if @logfiles.modified_before(path, since_ms) ||
      path.has_suffix("session-corrections.jsonl") {
      continue
    }
    let project = basename(dirname(path))
    let session = stem(basename(path))
    @logfiles.each_line(path, line => {
      if !@analysis.is_candidate_line(line) {
        return
      }
      if @analysis.claude_message(@utf8.decode_lossy(line), project~, session~)
        is Some(row) {
        rows.push(row)
      }
    })
  }
  for path in jsonl_files("\{home}/.codex/sessions", depth=4) {
    if @logfiles.modified_before(path, since_ms) {
      continue
    }
    let reader = @analysis.CodexSession::new(
      @analysis.take_last_chars(stem(basename(path)), 36),
    )
    @logfiles.each_line(path, line => {
      if !@analysis.is_candidate_line(line) {
        return
      }
      if reader.read_line(@utf8.decode_lossy(line)) is Some(row) {
        rows.push(row)
      }
    })
  }
  rows
}

///|
/// Removes the chunks of an earlier run on the same day, which may have left more files than this run writes.
async fn write_unmatched_chunks(
  out_dir : String,
  today : String,
  chunks : Array[Array[@analysis.Message]],
) -> Array[String] {
  let prefix = "\{today}-unmatched-"
  for name in @fs.readdir(out_dir, include_hidden=false) {
    if name.has_prefix(prefix) && name.has_suffix(".tsv") {
      @fs.remove("\{out_dir}/\{name}")
    }
  }
  let paths = []
  for i, chunk in chunks {
    let number = if i < 9 { "0\{i + 1}" } else { "\{i + 1}" }
    let path = "\{out_dir}/\{prefix}\{number}.tsv"
    write_lines(path, chunk.map(@analysis.unmatched_tsv_line))
    paths.push(path)
  }
  paths
}

///|
async fn previous_metrics(
  out_dir : String,
  today : String,
) -> @analysis.PreviousMetrics? {
  let names = @fs.readdir(out_dir, include_hidden=false).filter(name => {
    name.has_suffix("-metrics.json") &&
    !name.has_suffix("\{today}-metrics.json")
  })
  guard !names.is_empty() else { return None }
  names.sort_by((a, b) => a.lexical_compare(b))
  let latest = names[names.length() - 1]
  @analysis.parse_previous_metrics(
    read_text("\{out_dir}/\{latest}"),
    date=@analysis.take_chars(latest, 10),
  )
}

///|
/// The standard library has no time zone support, so the OS supplies Python's `date.today()` value.
async fn local_date() -> String {
  let (status, out) = @process.collect_stdout("date", ["+%Y-%m-%d"])
  guard status == 0 else { fail("date exited with status \{status}") }
  out.text().trim().to_owned()
}

///|
/// Matches Python glob's exact depth and exclusion of hidden entries.
async fn jsonl_files(root : String, depth~ : Int32) -> Array[String] {
  if !@fs.exists(root) {
    return []
  }
  let mut dirs = [root]
  for _ in 1..<depth {
    let next = []
    for dir in dirs {
      for name in @fs.readdir(dir, include_hidden=false) {
        let path = "\{dir}/\{name}"
        if @fs.kind(path, follow_symlink=true) is Directory {
          next.push(path)
        }
      }
    }
    dirs = next
  }
  let files = []
  for dir in dirs {
    for name in @fs.readdir(dir, include_hidden=false) {
      if name.has_suffix(".jsonl") {
        files.push("\{dir}/\{name}")
      }
    }
  }
  files
}

///|
async fn read_text(path : String) -> String {
  @utf8.decode_lossy(@fs.read_file(path).binary())
}

///|
async fn write_lines(path : String, lines : Array[String]) -> Unit {
  let out = StringBuilder()
  for line in lines {
    out.write_string(line)
    out.write_char('\n')
  }
  @fs.write_file(path, out.to_string())
}

///|
fn basename(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
}

///|
fn dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[:i].to_owned()
    None => ""
  }
}

///|
fn stem(name : String) -> String {
  match name.strip_suffix(".jsonl") {
    Some(s) => s.to_owned()
    None => name
  }
}
