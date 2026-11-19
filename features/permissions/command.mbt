///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "permissions",
    about="Summarize Claude Code permissions and sandbox failures",
    options=[
      @options.days(),
      @options.limit(),
      @options.projects(home),
      @argparse.OptionArg("events", long="events", default_values=[
        "\{home}/.local/state/claude/permission-events.jsonl",
      ]),
    ],
  )
}
