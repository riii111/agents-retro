///|
pub fn days() -> @argparse.OptionArg {
  @argparse.OptionArg(
    "days",
    long="days",
    default_values=["7"],
    allow_hyphen_values=true,
  )
}

///|
pub fn limit() -> @argparse.OptionArg {
  @argparse.OptionArg(
    "limit",
    long="limit",
    default_values=["15"],
    allow_hyphen_values=true,
  )
}

///|
pub fn projects(home : String) -> @argparse.OptionArg {
  @argparse.OptionArg("projects", long="projects", default_values=[
    "\{home}/.claude/projects",
  ])
}

///|
pub fn sessions(home : String) -> @argparse.OptionArg {
  @argparse.OptionArg("sessions", long="sessions", default_values=[
    "\{home}/.codex/sessions",
  ])
}

///|
/// The reporting period and list length chosen by `days()` and `limit()`.
pub struct Window {
  days : Int64
  limit : Int32
  since_ms : Int64
}

///|
pub fn Window::parse(
  matches : @argparse.Matches,
  now_ms : Int64,
) -> Window raise {
  let days = @string.parse_int64(matches.values["days"][0])
  let limit = @string.parse_int(matches.values["limit"][0])
  guard days >= 0L else { fail("--days must be non-negative") }
  guard limit >= 0 else { fail("--limit must be non-negative") }

  { days, limit, since_ms: now_ms - days * 86_400_000L, }
}
