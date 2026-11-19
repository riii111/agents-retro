///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "hooks",
    about="Summarize operations blocked by hooks as JSON",
    options=[@options.days(), @options.limit(), @options.projects(home)],
  )
}
