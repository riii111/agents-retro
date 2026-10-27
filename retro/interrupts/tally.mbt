///|
priv enum Event {
  Interrupt
  ToolUseInterrupt
  Rejection
}

///|
priv struct Tool {
  name : String
  command : String
} derive(Eq, Hash)

///|
priv struct Tally {
  mut interrupts : Int32
  mut tool_use_interrupts : Int32
  mut rejections : Int32
  mut sidechain : Int32
}

///|
priv struct SessionTally {
  id : String
  project : String
  sidechain : Bool
  tally : Tally
  tools : Map[Tool, Tally]
}

///|
fn Tally::new() -> Tally {
  { interrupts: 0, tool_use_interrupts: 0, rejections: 0, sidechain: 0, }
}

///|
fn Tally::add(self : Tally, event : Event, sidechain~ : Bool) -> Unit {
  match event {
    Interrupt => self.interrupts += 1
    ToolUseInterrupt => self.tool_use_interrupts += 1
    Rejection => self.rejections += 1
  }
  if sidechain {
    self.sidechain += 1
  }
}

///|
fn Tally::total(self : Tally) -> Int32 {
  self.interrupts + self.tool_use_interrupts + self.rejections
}
