///|
pub fn command() -> @argparse.Command {
  @argparse.Command(
    "messages",
    about="Collect the messages you typed to Claude Code and Codex",
    options=[
      OptionArg("days", long="days", default_values=["7"]),
      OptionArg(
        "patterns",
        long="patterns",
        about="JSON object of category name to regex",
        required=true,
      ),
      OptionArg(
        "out-dir",
        long="out-dir",
        about="Output directory",
        required=true,
      ),
    ],
  )
}
