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
    "days": @jsonreport.number(days),
    "records": @jsonreport.number(records.to_int64()),
    "total": tally_json([], self.total),
    "messages": @jsonreport.top(
      messages,
      limit,
      entry => entry.1.blocks.to_int64(),
      entry => {
        tally_json(
          [
            ("event", Json::string(entry.0.event)),
            ("message", Json::string(entry.0.message)),
          ],
          entry.1,
        )
      },
    ),
    "tools": @jsonreport.top(tools, limit, entry => entry.1.blocks.to_int64(), entry => {
      tally_json(
        [
          ("event", Json::string(entry.0.event)),
          ("tool", Json::string(entry.0.tool)),
        ],
        entry.1,
      )
    }),
    "commands": @jsonreport.top(
      commands,
      limit,
      entry => entry.1.blocks.to_int64(),
      entry => {
        tally_json(
          [
            ("tool", Json::string(entry.0.tool)),
            ("command", Json::string(entry.0.command)),
          ],
          entry.1,
        )
      },
    ),
  }).stringify() +
  "\n"
}

///|
fn tally_json(keys : Array[(String, Json)], tally : Tally) -> Json {
  @jsonreport.object(
    keys +
    [
      ("blocks", @jsonreport.number(tally.blocks.to_int64())),
      ("sessions", @jsonreport.number(tally.sessions.length().to_int64())),
      ("sidechain_blocks", @jsonreport.number(tally.sidechain.to_int64())),
    ],
  )
}
