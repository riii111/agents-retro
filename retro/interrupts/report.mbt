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
/// Resumed sessions copy earlier records into a new log file, so a record id is counted once.
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
  tally_of(self.projects, project).add(event, sidechain~)
  tally_of(self.tools, tool).add(event, sidechain~)

  if !self.project_sessions.contains(project) {
    self.project_sessions[project] = Set([])
  }
  self.project_sessions[project].add(session)

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
  tally_of(entry.tools, tool).add(event, sidechain~)
}

///|
fn[K : Hash + Eq] tally_of(tallies : Map[K, Tally], key : K) -> Tally {
  if !tallies.contains(key) {
    tallies[key] = Tally::new()
  }

  tallies[key]
}
