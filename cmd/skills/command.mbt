///|
pub fn command(home : String) -> @argparse.Command {
  @argparse.Command(
    "skills",
    about="Summarize skill and subagent use and list unused skills as JSON",
    options=[
      @options.days(),
      @options.limit(),
      @options.projects(home),
      @options.sessions(home),
      @argparse.OptionArg("claude-skills", long="claude-skills", default_values=[
        "\{home}/.claude/skills",
      ]),
      @argparse.OptionArg("codex-skills", long="codex-skills", default_values=[
        "\{home}/.codex/skills",
      ]),
    ],
  )
}
