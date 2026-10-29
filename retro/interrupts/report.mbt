///|
pub struct Report {
  priv seen : Set[String]
  priv total : Tally
  priv projects : Map[String, Tally]
  priv project_sessions : Map[String, Set[String]]
  priv sessions : Map[String, SessionTally]
  priv tools : Map[Tool, Tally]
}

///|
pub fn Report::new() -> Report {
  {
    seen: Set([]),
    total: Tally::new(),
    projects: Map([]),
    project_sessions: Map([]),
    sessions: Map([]),
    tools: Map([]),
  }
}

///|
/// Resumed sessions copy earlier records into a new log file, so an event id is counted once.
fn Report::add_event(
  self : Report,
  id : String,
  event : Event,
  session~ : String,
  project~ : String,
  sidechain~ : Bool,
  tool : Tool,
) -> Unit {
  guard id.is_empty() || self.seen.add_and_check(id) else { return }

  self.total.add(event, sidechain~)
  self.projects.get_or_init(project, Tally::new).add(event, sidechain~)
  self.tools.get_or_init(tool, Tally::new).add(event, sidechain~)

  self.project_sessions.get_or_init(project, () => Set([])).add(session)

  let key = "\{session}/\{sidechain}"
  if !self.sessions.contains(key) {
    self.sessions[key] = {
      id: session,
      project,
      sidechain,
      tally: Tally::new(),
      tools: Map([]),
    }
  }
  let entry = self.sessions[key]
  entry.tally.add(event, sidechain~)
  entry.tools.get_or_init(tool, Tally::new).add(event, sidechain~)
}
