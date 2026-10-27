///|
pub struct Report {
  priv seen : Set[String]
  priv seen_calls : Set[String]
  priv total : Failures
  priv tools : Map[Tool, Failures]
}

///|
pub fn Report::new() -> Report {
  {
    seen: Set([]),
    seen_calls: Set([]),
    total: Failures::new(),
    tools: Map([]),
  }
}

///|
/// Resumed sessions copy earlier history, so a tool use id is counted once.
/// A failure is a repeat when the same call already failed in the same session.
fn Report::add_failure(
  self : Report,
  id : String,
  call : Call,
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  guard !id.is_empty() && self.seen.add_and_check(id) else { return }

  let repeat = !self.seen_calls.add_and_check(
    "\{session}\n\{call.tool.name}\n\{call.input}",
  )
  self.total.add(session, sidechain~, repeat~)
  if !self.tools.contains(call.tool) {
    self.tools[call.tool] = Failures::new()
  }
  self.tools[call.tool].add(session, sidechain~, repeat~)
}
