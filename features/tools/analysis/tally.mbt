///|
priv struct Tool {
  name : String
  command : String
} derive(Eq, Hash)

///|
priv struct Call {
  tool : Tool
  input : String
}

///|
priv struct Failures {
  mut failures : Int32
  mut repeats : Int32
  mut sidechain : Int32
  sessions : Set[String]
}

///|
fn Failures::new() -> Failures {
  { failures: 0, repeats: 0, sidechain: 0, sessions: Set([]), }
}

///|
fn Failures::add(
  self : Failures,
  session : String,
  sidechain~ : Bool,
  repeat~ : Bool,
) -> Unit {
  self.failures += 1
  if repeat {
    self.repeats += 1
  }
  if sidechain {
    self.sidechain += 1
  }
  self.sessions.add(session)
}
