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
    "days": @jsonreport.number(days),
    "records": @jsonreport.number(records.to_int64()),
    "total": tally_json([], self.total),
    "projects": @jsonreport.top(projects, limit, entry => entry.1.total(), entry => {
      let sessions = self.project_sessions[entry.0].length().to_int64()
      tally_json(
        [
          ("project", Json::string(entry.0)),
          ("sessions", @jsonreport.number(sessions)),
        ],
        entry.1,
      )
    }),
    "sessions": @jsonreport.top(sessions, limit, s => s.tally.total(), s => {
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
    "previous_tools": @jsonreport.top(
      previous_tools,
      limit,
      entry => entry.1.total(),
      entry => {
        tally_json(
          [
            ("tool", Json::string(entry.0.name)),
            ("command", Json::string(entry.0.command)),
          ],
          entry.1,
        )
      },
    ),
    "tool_results": @jsonreport.top(
      result_sizes,
      limit,
      entry => entry.1.chars,
      entry => {
        Json::object({
          "tool": Json::string(entry.0.name),
          "command": Json::string(entry.0.command),
          "results": @jsonreport.number(entry.1.results.to_int64()),
          "chars": @jsonreport.number(entry.1.chars),
        })
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
      ("responses", @jsonreport.number(tally.responses.to_int64())),
      ("input", @jsonreport.number(tally.input)),
      ("cache_creation", @jsonreport.number(tally.cache_creation)),
      ("cache_read", @jsonreport.number(tally.cache_read)),
      ("output", @jsonreport.number(tally.output)),
      ("total", @jsonreport.number(tally.total())),
      ("sidechain_total", @jsonreport.number(tally.sidechain)),
      ("cache_read_ratio", Json::number(tally.cache_read_ratio())),
    ],
  )
}
