///|
async fn main {
  guard @env.get_env_var("HOME") is Some(home) else { fail("HOME is not set") }
  let now_ms = @env.now().reinterpret_as_int64()
  let matches = command(home).parse()

  match matches.subcommand {
    Some(("interrupts", interrupts)) => @interrupts.run(interrupts, now_ms)
    Some(("messages", messages)) => @messages.run(messages, home, now_ms)
    Some(("permissions", permissions)) =>
      @permissions.run(permissions, home, now_ms)
    Some(("tokens", tokens)) => @tokens.run(tokens, now_ms)
    Some(("tools", tools)) => @tools.run(tools, now_ms)
    _ => fail("a subcommand is required")
  }
}

///|
const VERSION = "0.1.0"

///|
fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "agents-retro",
    about="Review what keeps interrupting your work with Claude Code and Codex",
    version=VERSION,
    arg_required_else_help=true,
    subcommand_required=true,
    subcommands=[
      @interrupts.command(home),
      @messages.command(),
      @permissions.command(home),
      @tokens.command(home),
      @tools.command(home),
    ],
  )
}
