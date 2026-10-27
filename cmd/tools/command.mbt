///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command("tools", about="Summarize failed tool calls as JSON", options=[
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
  ])
}

///|
fn report_options(matches : @argparse.Matches) -> (Int64, Int32) raise {
  let days = @string.parse_int64(matches.values["days"][0])
  let limit = @string.parse_int(matches.values["limit"][0])
  guard days >= 0L else { fail("--days must be non-negative") }
  guard limit >= 0 else { fail("--limit must be non-negative") }

  (days, limit)
}
