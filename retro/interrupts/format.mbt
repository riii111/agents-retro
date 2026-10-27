///|
/// Every list is ordered by count, largest first.
pub fn Report::to_json(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
) -> String {
  let projects : Array[(String, Tally)] = self.projects.iter().collect()
  let sessions : Array[SessionTally] = self.sessions.values().collect()

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
      let tools : Array[(Tool, Tally)] = s.tools.iter().collect()
      tally_json(
        [
          ("session", Json::string(s.id)),
          ("project", Json::string(s.project)),
          ("sidechain", Json::boolean(s.sidechain)),
          ("tools", tools_json(tools, limit)),
        ],
        s.tally,
      )
    }),
    "tools": tools_json(self.tools.iter().collect(), limit),
  }).stringify() +
  "\n"
}

///|
fn number(n : Int64) -> Json {
  Json::number(n.to_double())
}

///|
fn tools_json(tools : Array[(Tool, Tally)], limit : Int32) -> Json {
  top(tools, limit, entry => entry.1.total(), entry => {
    tally_json(
      [
        ("tool", Json::string(entry.0.name)),
        ("command", Json::string(entry.0.command)),
      ],
      entry.1,
    )
  })
}

///|
fn tally_json(keys : Array[(String, Json)], tally : Tally) -> Json {
  let fields : Map[String, Json] = Map([])
  for key in keys {
    fields[key.0] = key.1
  }

  fields["interrupts"] = number(tally.interrupts.to_int64())
  fields["tool_use_interrupts"] = number(tally.tool_use_interrupts.to_int64())
  fields["rejections"] = number(tally.rejections.to_int64())
  fields["total"] = number(tally.total().to_int64())
  fields["sidechain_total"] = number(tally.sidechain.to_int64())
  Json::object(fields)
}

///|
fn[T] top(
  items : Array[T],
  limit : Int32,
  size : (T) -> Int32,
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
