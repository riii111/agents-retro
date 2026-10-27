///|
/// Every list is ordered by block count, most blocked first.
pub fn Report::to_json(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
) -> String {
  let messages : Array[(MessageKey, Tally)] = self.messages.iter().collect()
  let tools : Array[(ToolKey, Tally)] = self.tools.iter().collect()
  let commands : Array[(CommandKey, Tally)] = self.commands.iter().collect()

  Json::object({
    "days": number(days),
    "records": number(records.to_int64()),
    "total": tally_json([], self.total),
    "messages": top(messages, limit, entry => {
      tally_json(
        [
          ("event", Json::string(entry.0.event)),
          ("message", Json::string(entry.0.message)),
        ],
        entry.1,
      )
    }),
    "tools": top(tools, limit, entry => {
      tally_json(
        [
          ("event", Json::string(entry.0.event)),
          ("tool", Json::string(entry.0.tool)),
        ],
        entry.1,
      )
    }),
    "commands": top(commands, limit, entry => {
      tally_json(
        [
          ("tool", Json::string(entry.0.tool)),
          ("command", Json::string(entry.0.command)),
        ],
        entry.1,
      )
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

  fields["blocks"] = number(tally.blocks.to_int64())
  fields["sessions"] = number(tally.sessions.length().to_int64())
  fields["sidechain_blocks"] = number(tally.sidechain.to_int64())
  Json::object(fields)
}

///|
fn[K] top(
  items : Array[(K, Tally)],
  limit : Int32,
  render : ((K, Tally)) -> Json,
) -> Json {
  let ranked = items.mapi((i, item) => (item, i))
  ranked.sort_by((a, b) => {
    let by_blocks = b.0.1.blocks.compare(a.0.1.blocks)
    if by_blocks == 0 {
      a.1.compare(b.1)
    } else {
      by_blocks
    }
  })

  Json::array(ranked.iter().take(limit).map(entry => render(entry.0)).collect())
}
