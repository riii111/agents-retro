///|
pub struct Report {
  priv seen : Set[String]
  priv skills : Map[SkillUse, Tally]
  priv subagents : Map[SubagentUse, Tally]
  priv used : Set[String]
}

///|
pub fn Report::new() -> Report {
  { seen: Set([]), skills: Map([]), subagents: Map([]), used: Set([]), }
}

///|
/// Logs can repeat one tool call, so a call id is counted once.
fn Report::first_seen(self : Report, id : String) -> Bool {
  !id.is_empty() && self.seen.add_and_check(id)
}

///|
fn Report::add_skill(
  self : Report,
  source~ : String,
  name~ : String,
  via~ : String,
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  self.used.add("\{source}/\{bare_name(name)}")
  tally_of(self.skills, { source, name, via, }).add(session, sidechain~)
}

///|
fn Report::add_subagent(
  self : Report,
  source~ : String,
  subagent_type~ : String,
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  tally_of(self.subagents, { source, subagent_type, }).add(session, sidechain~)
}

///|
fn[K : Hash + Eq] tally_of(tallies : Map[K, Tally], key : K) -> Tally {
  if !tallies.contains(key) {
    tallies[key] = Tally::new()
  }

  tallies[key]
}
