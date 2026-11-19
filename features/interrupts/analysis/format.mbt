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
    "days": @jsonreport.number(days),
    "records": @jsonreport.number(records.to_int64()),
    "total": tally_json([], self.total),
    "projects": @jsonreport.top(
      projects,
      limit,
      entry => entry.1.total().to_int64(),
      entry => {
        let sessions = self.project_sessions[entry.0].length().to_int64()
        tally_json(
          [
            ("project", Json::string(entry.0)),
            ("sessions", @jsonreport.number(sessions)),
          ],
          entry.1,
        )
      },
    ),
    "sessions": @jsonreport.top(
      sessions,
      limit,
      s => s.tally.total().to_int64(),
      s => {
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
      },
    ),
    "tools": tools_json(self.tools.iter().collect(), limit),
  }).stringify() +
  "\n"
}

///|
fn tools_json(tools : Array[(Tool, Tally)], limit : Int32) -> Json {
  @jsonreport.top(tools, limit, entry => entry.1.total().to_int64(), entry => {
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
  @jsonreport.object(
    keys +
    [
      ("interrupts", @jsonreport.number(tally.interrupts.to_int64())),
      (
        "tool_use_interrupts",
        @jsonreport.number(tally.tool_use_interrupts.to_int64()),
      ),
      ("rejections", @jsonreport.number(tally.rejections.to_int64())),
      ("total", @jsonreport.number(tally.total().to_int64())),
      ("sidechain_total", @jsonreport.number(tally.sidechain.to_int64())),
    ],
  )
}
