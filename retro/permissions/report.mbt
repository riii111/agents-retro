///|
struct Counter {
  counts : Map[String, Int32]
}

///|
pub struct Report {
  priv home : String
  priv prompts : Events
  priv denials : Events
  priv causes : Counter
  priv reruns : Counter
  priv failed : Counter
  priv writes : Counter
  priv hosts : Counter
}

///|
struct Events {
  shapes : Counter
  commands : Counter
  places : Counter
  sessions : Map[String, Set[String]]
}

///|
pub fn Report::new(home~ : String) -> Report {
  {
    home,
    prompts: Events::new(),
    denials: Events::new(),
    causes: Counter::new(),
    reruns: Counter::new(),
    failed: Counter::new(),
    writes: Counter::new(),
    hosts: Counter::new(),
  }
}

///|
fn Events::new() -> Events {
  {
    shapes: Counter::new(),
    commands: Counter::new(),
    places: Counter::new(),
    sessions: Map([]),
  }
}

///|
fn Counter::new() -> Counter {
  { counts: Map([]), }
}

///|
fn Counter::add(self : Counter, key : String) -> Unit {
  self.counts[key] = self.counts.get_or_default(key, 0) + 1
}
