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
  let days = @string.parse_int64(matches.values["days"][0])
  let limit = @string.parse_int(matches.values["limit"][0])
  guard days >= 0L else { fail("--days must be non-negative") }
  guard limit >= 0 else { fail("--limit must be non-negative") }
  let since_ms = now_ms - days * 86_400_000L
  let report = @analysis.Report::new(home~)
  let records = records(matches.values["projects"][0], since_ms)
  for path in records {
    let session = report.start_session()
    @logfiles.each_line(path, line => {
      if @analysis.is_candidate_line(line) {
        session.read_line(@utf8.decode_lossy(line))
      }
    })
  }
  let events = matches.values["events"][0]
  if @fs.exists(events) {
    @logfiles.each_line(events, line => {
      report.read_event(@utf8.decode_lossy(line), since_ms~)
    })
  }
  report.format(days~, records=records.length(), limit~)
}

///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "permissions",
    about="Summarize Claude Code permissions and sandbox failures",
    options=[
      OptionArg(
        "days",
        long="days",
        default_values=["7"],
        allow_hyphen_values=true,
      ),
      OptionArg(
        "limit",
        long="limit",
        default_values=["15"],
        allow_hyphen_values=true,
      ),
      OptionArg("projects", long="projects", default_values=[
        "\{home}/.claude/projects",
      ]),
      OptionArg("events", long="events", default_values=[
        "\{home}/.local/state/claude/permission-events.jsonl",
      ]),
    ],
  )
}

///|
async fn records(root : String, since_ms : Int64) -> Array[String] {
  let records = []
  if !@fs.exists(root) || @fs.kind(root, follow_symlink=true) != Directory {
    return records
  }
  walk(root, since_ms, records)
  records
}

///|
async fn walk(root : String, since_ms : Int64, records : Array[String]) -> Unit {
  let names = @fs.readdir(root, include_hidden=true)
  for name in names {
    let path = "\{root}/\{name}"
    if !name.has_suffix(".jsonl") {
      continue
    }
    let kind = @fs.kind(path, follow_symlink=true) catch { _ => continue }
    if kind is Regular && !@logfiles.modified_before(path, since_ms) {
      records.push(path)
    }
  }
  for name in names {
    let path = "\{root}/\{name}"
    if @fs.kind(path, follow_symlink=false) is Directory {
      walk(path, since_ms, records)
    }
  }
}
