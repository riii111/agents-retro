///|
priv struct Block {
  event : String
  tool : String
  command : String
  message : String
  session : String
  sidechain : Bool
}

///|
priv struct MessageKey {
  event : String
  message : String
} derive(Eq, Hash)

///|
priv struct ToolKey {
  event : String
  tool : String
} derive(Eq, Hash)

///|
priv struct CommandKey {
  tool : String
  command : String
} derive(Eq, Hash)

///|
priv struct Tally {
  mut blocks : Int32
  mut sidechain : Int32
  sessions : Set[String]
}

///|
fn Tally::new() -> Tally {
  { blocks: 0, sidechain: 0, sessions: Set([]), }
}

///|
fn Tally::add(self : Tally, session : String, sidechain~ : Bool) -> Unit {
  self.blocks += 1
  self.sessions.add(session)
  if sidechain {
    self.sidechain += 1
  }
}
