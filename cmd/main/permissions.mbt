///|
async fn permissions_main(args : ArrayView[String]) -> Unit {
  guard @env.get_env_var("HOME") is Some(home) else { fail("HOME is not set") }
  let matches = permission_command(home).parse(argv=args)
  let days = @string.parse_int64(matches.values["days"][0])
  let limit = @string.parse_int(matches.values["limit"][0])
  let since_ms = @env.now().reinterpret_as_int64() - days * 86_400_000L
  let report = @retro.PermissionReport::new(home~)
  let records = permission_records(matches.values["projects"][0], since_ms)
  for path in records {
    report.scan_session(read_permission_text(path))
  }
  let events = matches.values["events"][0]
  if @fs.exists(events) {
    report.scan_events(
      read_permission_text(events),
      since_ms=@env.now().reinterpret_as_int64() - days * 86_400_000L,
    )
  }
  let output = report.format(days~, records=records.length(), limit~)
  println(output[:output.length() - 1])
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
    if name.has_suffix(".jsonl") && !modified_before(path, since_ms) {
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

///|
/// Python reads these logs with errors="ignore"; valid replacement characters must survive.
async fn read_permission_text(path : String) -> String {
  let bytes = @fs.read_file(path).binary()
  let out = StringBuilder()
  let mut rest : BytesView = bytes
  while !rest.is_empty() {
    try {
      out.write_string(@utf8.decode(rest))
      break
    } catch {
      @utf8.Malformed(suffix) => {
        let valid = rest.length() - suffix.length()
        out.write_string(@utf8.decode_lossy(rest[:valid]))
        rest = suffix[1:]
      }
    }
  }
  out.to_string()
}
