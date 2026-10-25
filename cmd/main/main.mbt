///|
async fn main {
  guard @env.get_env_var("HOME") is Some(home) else { fail("HOME is not set") }
  let now_ms = @env.now().reinterpret_as_int64()
  let matches = command(home).parse()
  match matches.subcommand {
    Some(("permissions", permissions)) =>
      @permissions.run(permissions, home, now_ms)
    _ => @messages.run(matches, home, now_ms)
  }
}

///|
fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "agents-retro",
    about="Collect the messages you typed to Claude Code and Codex",
    options=@messages.options(),
    subcommands=[@permissions.command(home)],
  )
}
