///|
priv struct SkillUse {
  source : String
  name : String
  via : String
} derive(Eq, Hash)

///|
priv struct SubagentUse {
  source : String
  subagent_type : String
} derive(Eq, Hash)

///|
priv struct Tally {
  mut invocations : Int32
  mut sidechain : Int32
  sessions : Set[String]
}

///|
fn Tally::new() -> Tally {
  { invocations: 0, sidechain: 0, sessions: Set([]), }
}

///|
fn Tally::add(self : Tally, session : String, sidechain~ : Bool) -> Unit {
  self.invocations += 1
  if sidechain {
    self.sidechain += 1
  }
  self.sessions.add(session)
}

///|
/// Plugin skills are logged as `plugin:name`, while skill directories use the bare name.
fn bare_name(name : String) -> String {
  match name.rev_find(":") {
    Some(i) => name[i + 1:].to_owned()
    None => name
  }
}
