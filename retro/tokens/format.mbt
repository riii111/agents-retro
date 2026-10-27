///|
/// Every list is ordered by size, largest first.
pub fn Report::to_json(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
) -> String {
  let projects : Array[(String, Tally)] = self.projects.iter().collect()
  let sessions : Array[SessionTally] = self.sessions.values().collect()
  let previous_tools : Array[(Tool, Tally)] = self.previous_tools
    .iter()
    .collect()
  let result_sizes : Array[(Tool, ResultSize)] = self.result_sizes
    .iter()
    .collect()

  Json::object({
    "days": number(days),
    "records": number(records.to_int64()),
    "total": tally_json([], self.total),
    "projects": top(projects, limit, entry => entry.1.total(), entry => {
      let sessions = self.project_sessions[entry.0].length().to_int64()
      tally_json(
        [("project", Json::string(entry.0)), ("sessions", number(sessions))],
        entry.1,
      )
    }),
    "sessions": top(sessions, limit, s => s.tally.total(), s => {
      tally_json(
        [
          ("source", Json::string(s.source)),
          ("session", Json::string(s.id)),
          ("project", Json::string(s.project)),
          ("sidechain", Json::boolean(s.sidechain)),
        ],
        s.tally,
      )
    }),
    "previous_tools": top(previous_tools, limit, entry => entry.1.total(), entry => {
      tally_json(
        [
          ("tool", Json::string(entry.0.name)),
          ("command", Json::string(entry.0.command)),
        ],
        entry.1,
      )
    }),
    "tool_results": top(result_sizes, limit, entry => entry.1.chars, entry => {
      Json::object({
        "tool": Json::string(entry.0.name),
        "command": Json::string(entry.0.command),
        "results": number(entry.1.results.to_int64()),
        "chars": number(entry.1.chars),
      })
    }),
  }).stringify() +
  "\n"
}

///|
fn number(n : Int64) -> Json {
  Json::number(n.to_double())
}

///|
fn tally_json(keys : Array[(String, Json)], tally : Tally) -> Json {
  let fields : Map[String, Json] = Map([])
  for key in keys {
    fields[key.0] = key.1
  }

  fields["responses"] = number(tally.responses.to_int64())
  fields["input"] = number(tally.input)
  fields["cache_creation"] = number(tally.cache_creation)
  fields["cache_read"] = number(tally.cache_read)
  fields["output"] = number(tally.output)
  fields["total"] = number(tally.total())
  fields["sidechain_total"] = number(tally.sidechain)
  fields["cache_read_ratio"] = Json::number(tally.cache_read_ratio())
  Json::object(fields)
}

///|
fn[T] top(
  items : Array[T],
  limit : Int32,
  size : (T) -> Int64,
  render : (T) -> Json,
) -> Json {
  let ranked = items.mapi((i, item) => (item, i))
  ranked.sort_by((a, b) => {
    let by_size = size(b.0).compare(size(a.0))
    if by_size == 0 {
      a.1.compare(b.1)
    } else {
      by_size
    }
  })

  Json::array(ranked.iter().take(limit).map(entry => render(entry.0)).collect())
}
