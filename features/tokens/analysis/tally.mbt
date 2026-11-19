///|
priv struct Usage {
  input : Int64
  cache_creation : Int64
  cache_read : Int64
  output : Int64
}

///|
priv struct Tally {
  mut responses : Int32
  mut input : Int64
  mut cache_creation : Int64
  mut cache_read : Int64
  mut output : Int64
  mut sidechain : Int64
}

///|
priv struct Tool {
  name : String
  command : String
} derive(Eq, Hash)

///|
priv struct ResultSize {
  mut results : Int32
  mut chars : Int64
}

///|
priv struct SessionTally {
  source : String
  id : String
  project : String
  sidechain : Bool
  tally : Tally
}

///|
fn Tally::new() -> Tally {
  {
    responses: 0,
    input: 0L,
    cache_creation: 0L,
    cache_read: 0L,
    output: 0L,
    sidechain: 0L,
  }
}

///|
fn Tally::add(self : Tally, usage : Usage, sidechain~ : Bool) -> Unit {
  self.responses += 1
  self.input += usage.input
  self.cache_creation += usage.cache_creation
  self.cache_read += usage.cache_read
  self.output += usage.output
  if sidechain {
    self.sidechain += usage.input +
      usage.cache_creation +
      usage.cache_read +
      usage.output
  }
}

///|
fn Tally::total(self : Tally) -> Int64 {
  self.input + self.cache_creation + self.cache_read + self.output
}

///|
/// Share of the input-side tokens that were served from the prompt cache.
fn Tally::cache_read_ratio(self : Tally) -> Double {
  let input_side = self.input + self.cache_creation + self.cache_read
  if input_side == 0L {
    return 0.0
  }

  let ratio = self.cache_read.to_double() / input_side.to_double()
  (ratio * 1000.0).round() / 1000.0
}

///|
fn ResultSize::new() -> ResultSize {
  { results: 0, chars: 0L, }
}
