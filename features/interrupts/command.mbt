///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "interrupts",
    about="Summarize user interruptions and rejected tool calls as JSON",
    options=[@options.days(), @options.limit(), @options.projects(home)],
  )
}
