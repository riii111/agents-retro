///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command("tools", about="Summarize failed tool calls as JSON", options=[
    @options.days(),
    @options.limit(),
    @options.projects(home),
  ])
}
