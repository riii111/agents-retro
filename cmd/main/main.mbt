///|
async fn main {
  let matches = @argparse.Command(
    "agents-retro",
    about="Collect the messages you typed to Claude Code and Codex",
    options=[
      OptionArg("days", long="days", default_values=["7"]),
      OptionArg(
        "patterns",
        long="patterns",
        required=true,
        about="JSON object of category name to regex",
      ),
      OptionArg("out-dir", long="out-dir", required=true),
    ],
  ).parse()
  let days = @string.parse_int64(matches.values["days"][0])
  let patterns_path = matches.values["patterns"][0]
  let out_dir = matches.values["out-dir"][0]
  guard @env.get_env_var("HOME") is Some(home) else { fail("HOME is not set") }

  let now_ms = @env.now().reinterpret_as_int64()
  let since_ms = now_ms - days * 86_400_000L
  let today = local_date()
  let patterns = @retro.parse_patterns(read_text(patterns_path))
  let since = @retro.utc_isoformat(since_ms)
  let (messages, delegated) = @retro.collect(read_logs(home, since_ms), since~)
  @fs.mkdir(out_dir, recursive=true, allow_exist=true)

  let messages_path = "\{out_dir}/\{today}-messages.tsv"
  write_lines(messages_path, messages.map(@retro.message_tsv_line))

  let hits = @retro.match_patterns(messages, patterns)
  let examples_path = "\{out_dir}/\{today}-examples.tsv"
  write_lines(
    examples_path,
    @retro.pattern_examples(hits).map(e => @retro.example_tsv_line(e.0, e.1)),
  )
  let chunks = @retro.unmatched_chunks(messages, hits)
  let unmatched_paths = write_unmatched_chunks(out_dir, today, chunks)

  let metrics : @retro.Metrics = {
    since,
    messages: messages.length(),
    sessions: @retro.session_count(messages),
    delegated,
    by_role: @retro.count_by_role(messages),
    unmatched: chunks.fold(init=0, (n, chunk) => n + chunk.length()),
    patterns: @retro.count_patterns(hits),
  }
  @fs.write_file("\{out_dir}/\{today}-metrics.json", metrics.to_json())

  println(
    @retro.format_summary(
      metrics,
      previous_metrics(out_dir, today),
      examples_path~,
      unmatched_paths~,
      messages_path~,
    ),
  )
}

///|
async fn read_logs(home : String, since_ms : Int64) -> Array[@retro.RawMessage] {
  let rows = []
  for path in jsonl_files("\{home}/.claude/projects", depth=2) {
    if modified_before(path, since_ms) ||
      path.has_suffix("session-corrections.jsonl") {
      continue
    }
    let project = basename(dirname(path))
    rows.append(
      @retro.claude_messages(
        read_candidate_lines(path),
        project~,
        session=stem(basename(path)),
      ),
    )
  }
  for path in jsonl_files("\{home}/.codex/sessions", depth=4) {
    if modified_before(path, since_ms) {
      continue
    }
    let session = stem(basename(path))
    let session = @retro.take_last_chars(session, 36)
    rows.append(@retro.codex_messages(read_candidate_lines(path), session~))
  }
  rows
}

///|
/// Removes the chunks of an earlier run on the same day, which may have left more files than this run writes.
async fn write_unmatched_chunks(
  out_dir : String,
  today : String,
  chunks : Array[Array[@retro.Message]],
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
    write_lines(path, chunk.map(@retro.unmatched_tsv_line))
    paths.push(path)
  }
  paths
}

///|
async fn previous_metrics(
  out_dir : String,
  today : String,
) -> @retro.PreviousMetrics? {
  let names = @fs.readdir(out_dir, include_hidden=false).filter(name => {
    name.has_suffix("-metrics.json") &&
    !name.has_suffix("\{today}-metrics.json")
  })
  guard !names.is_empty() else { return None }
  names.sort_by((a, b) => a.lexical_compare(b))
  let latest = names[names.length() - 1]
  @retro.parse_previous_metrics(
    read_text("\{out_dir}/\{latest}"),
    date=@retro.take_chars(latest, 10),
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
async fn modified_before(path : String, ms : Int64) -> Bool {
  let (sec, nsec) = @fs.mtime(path)
  sec * 1000L + (nsec / 1_000_000).to_int64() < ms
}

///|
/// Reads the file in chunks and decodes only candidate lines, so neither the whole file nor its UTF-16 copy stays in memory.
async fn read_candidate_lines(path : String) -> Array[String] {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let lines = []
  let keep = (line : BytesView) => {
    if @retro.is_candidate_line(line) {
      lines.push(@utf8.decode_lossy(line))
    }
  }
  let partial = Buffer()
  while file.read_some(max_len=1 << 20) is Some(chunk) {
    let mut start = 0
    for i in 0..<chunk.length() {
      if chunk[i] != b'\n' {
        continue
      }
      if partial.is_empty() {
        keep(chunk[start:i])
      } else {
        partial.write_bytesview(chunk[start:i])
        keep(partial.to_bytes())
        partial.reset()
      }
      start = i + 1
    }
    partial.write_bytesview(chunk[start:])
  }
  if !partial.is_empty() {
    keep(partial.to_bytes())
  }
  lines
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
