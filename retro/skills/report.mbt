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
/// Resumed sessions copy a user record into a new log file, so a record with an id is counted once.
fn Report::first_record(self : Report, uuid : String) -> Bool {
  uuid.is_empty() || self.seen.add_and_check("record/\{uuid}")
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
  self.skills
  .get_or_init({ source, name, via, }, Tally::new)
  .add(session, sidechain~)
}

///|
fn Report::add_subagent(
  self : Report,
  source~ : String,
  subagent_type~ : String,
  session~ : String,
  sidechain~ : Bool,
) -> Unit {
  self.subagents
  .get_or_init({ source, subagent_type, }, Tally::new)
  .add(session, sidechain~)
}
