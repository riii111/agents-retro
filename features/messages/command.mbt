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
      OptionArg(
        "candidates",
        long="candidates",
        about="JSON object of candidate name to regex, counted apart from the patterns",
      ),
    ],
    flags=[
      FlagArg(
        "by-week",
        long="by-week",
        about="Also list each UTC week (Monday 00:00 start) by app; compare with earlier runs only when the period matches",
      ),
    ],
  )
}
