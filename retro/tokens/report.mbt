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
  self.projects.get_or_init(project, Tally::new).add(usage, sidechain~)
  self.previous_tools.get_or_init(previous, Tally::new).add(usage, sidechain~)

  let session_key = "\{source}/\{session}"
  self.project_sessions.get_or_init(project, () => Set([])).add(session_key)

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
  let size = self.result_sizes.get_or_init(tool, ResultSize::new)
  size.results += 1
  size.chars += chars.to_int64()
}
