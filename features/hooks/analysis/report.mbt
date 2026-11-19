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
  self.messages
  .get_or_init({ event: block.event, message: block.message, }, Tally::new)
  .add(session, sidechain~)
  if !block.tool.is_empty() {
    self.tools
    .get_or_init({ event: block.event, tool: block.tool, }, Tally::new)
    .add(session, sidechain~)
  }
  if !block.command.is_empty() {
    self.commands
    .get_or_init({ tool: block.tool, command: block.command, }, Tally::new)
    .add(session, sidechain~)
  }
}
