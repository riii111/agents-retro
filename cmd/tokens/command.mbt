///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "tokens",
    about="Summarize token usage and tool result sizes as JSON",
    options=[
      @options.days(),
      @options.limit(),
      @options.projects(home),
      @options.sessions(home),
    ],
  )
}
