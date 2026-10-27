///|
pub struct Report {
  priv seen : Set[String]
  priv total : Tally
  priv messages : Map[MessageKey, Tally]
  priv tools : Map[ToolKey, Tally]
  priv commands : Map[CommandKey, Tally]
}

///|
pub fn Report::new() -> Report {
  {
    seen: Set([]),
    total: Tally::new(),
    messages: Map([]),
    tools: Map([]),
    commands: Map([]),
  }
}

///|
/// Resumed sessions copy earlier records, so a block id is counted once.
fn Report::add_block(self : Report, id : String, block : Block) -> Unit {
  guard !id.is_empty() && self.seen.add_and_check(id) else { return }

  let session = block.session
  let sidechain = block.sidechain
  self.total.add(session, sidechain~)
  tally_of(self.messages, { event: block.event, message: block.message, }).add(
    session,
    sidechain~,
  )
  if !block.tool.is_empty() {
    tally_of(self.tools, { event: block.event, tool: block.tool, }).add(
      session,
      sidechain~,
    )
  }
  if !block.command.is_empty() {
    tally_of(self.commands, { tool: block.tool, command: block.command, }).add(
      session,
      sidechain~,
    )
  }
}

///|
fn[K : Hash + Eq] tally_of(tallies : Map[K, Tally], key : K) -> Tally {
  if !tallies.contains(key) {
    tallies[key] = Tally::new()
  }

  tallies[key]
}
