///|
pub struct Report {
  priv seen : Set[String]
  priv total : Tally
  priv projects : Map[String, Tally]
  priv project_sessions : Map[String, Set[String]]
  priv sessions : Map[String, SessionTally]
  priv previous_tools : Map[Tool, Tally]
  priv result_sizes : Map[Tool, ResultSize]
}

///|
pub fn Report::new() -> Report {
  {
    seen: Set([]),
    total: Tally::new(),
    projects: Map([]),
    project_sessions: Map([]),
    sessions: Map([]),
    previous_tools: Map([]),
    result_sizes: Map([]),
  }
}

///|
/// Logs repeat one response on several lines, so a response id is counted once.
fn Report::add_response(
  self : Report,
  id : String,
  source~ : String,
  session~ : String,
  project~ : String,
  sidechain~ : Bool,
  previous~ : Tool,
  usage : Usage,
) -> Unit {
  guard !id.is_empty() && self.seen.add_and_check(id) else { return }

  self.total.add(usage, sidechain~)
  tally_of(self.projects, project).add(usage, sidechain~)
  tally_of(self.previous_tools, previous).add(usage, sidechain~)

  let session_key = "\{source}/\{session}"
  if !self.project_sessions.contains(project) {
    self.project_sessions[project] = Set([])
  }
  self.project_sessions[project].add(session_key)

  let key = "\{session_key}/\{sidechain}"
  if !self.sessions.contains(key) {
    self.sessions[key] = {
      source,
      id: session,
      project,
      sidechain,
      tally: Tally::new(),
    }
  }
  self.sessions[key].tally.add(usage, sidechain~)
}

///|
fn Report::add_result(self : Report, tool : Tool, chars : Int32) -> Unit {
  if !self.result_sizes.contains(tool) {
    self.result_sizes[tool] = ResultSize::new()
  }
  let size = self.result_sizes[tool]
  size.results += 1
  size.chars += chars.to_int64()
}

///|
fn[K : Hash + Eq] tally_of(tallies : Map[K, Tally], key : K) -> Tally {
  if !tallies.contains(key) {
    tallies[key] = Tally::new()
  }

  tallies[key]
}
