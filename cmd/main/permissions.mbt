///|
async fn permission_report(
  matches : @argparse.Matches,
  home : String,
  now_ms : Int64,
) -> String {
  let days = @string.parse_int64(matches.values["days"][0])
  let limit = @string.parse_int(matches.values["limit"][0])
  guard days >= 0L else { fail("--days must be non-negative") }
  guard limit >= 0 else { fail("--limit must be non-negative") }
  let since_ms = now_ms - days * 86_400_000L
  let report = @retro.PermissionReport::new(home~)
  let records = permission_records(matches.values["projects"][0], since_ms)
  for path in records {
    let session = report.start_session()
    each_line(path, line => session.read_line(@utf8.decode_lossy(line)))
  }
  let events = matches.values["events"][0]
  if @fs.exists(events) {
    each_line(events, line => {
      report.read_event(@utf8.decode_lossy(line), since_ms~)
    })
  }
  report.format(days~, records=records.length(), limit~)
}

///|
fn permission_command(home : String) -> @argparse.Command {
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
/// pathlib.rglob visits matching entries before descending, without following directory symlinks.
async fn permission_records(root : String, since_ms : Int64) -> Array[String] {
  let records = []
  if !@fs.exists(root) || @fs.kind(root, follow_symlink=true) != Directory {
    return records
  }
  permission_walk(root, since_ms, records)
  records
}

///|
async fn permission_walk(
  root : String,
  since_ms : Int64,
  records : Array[String],
) -> Unit {
  let names = @fs.readdir(root, include_hidden=true)
  for name in names {
    let path = "\{root}/\{name}"
    if name.has_suffix(".jsonl") &&
      @fs.kind(path, follow_symlink=true) is Regular &&
      !modified_before(path, since_ms) {
      records.push(path)
    }
  }
  for name in names {
    let path = "\{root}/\{name}"
    if @fs.kind(path, follow_symlink=false) is Directory {
      permission_walk(path, since_ms, records)
    }
  }
}
