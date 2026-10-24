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
/// The standard library has no time zone support, so the OS supplies the
/// local date that Python's `date.today()` uses.
async fn local_date() -> String {
  let (status, out) = @process.collect_stdout("date", ["+%Y-%m-%d"])
  guard status == 0 else { fail("date exited with status \{status}") }
  out.text().trim().to_owned()
}

///|
async fn read_text(path : String) -> String {
  @utf8.decode_lossy(@fs.read_file(path).binary())
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
        read_text(path),
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
    rows.append(@retro.codex_messages(read_text(path), session~))
  }
  rows
}

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
  let (messages, delegated) = @retro.collect(
    read_logs(home, since_ms),
    since=@retro.utc_isoformat(since_ms),
  )
  @fs.mkdir(out_dir, recursive=true, allow_exist=true)

  let messages_path = "\{out_dir}/\{today}-messages.tsv"
  let tsv = StringBuilder()
  for m in messages {
    tsv.write_string(@retro.message_tsv_line(m))
    tsv.write_char('\n')
  }
  @fs.write_file(messages_path, tsv.to_string())

  println(
    "Owner messages: \{messages.length()} in \{@retro.session_count(messages)} sessions (agent-to-agent messages excluded: \{delegated})",
  )
  for entry in @retro.count_by_role(messages) {
    println("  \{entry.0}: \{entry.1}")
  }
  println("\nPatterns (messages / sessions)")
  for c in @retro.count_patterns(messages, patterns) {
    println("  \{c.name}: \{c.messages} / \{c.sessions}")
  }
  println("Messages (full text, line number = id): \{messages_path}")
}
