///|
/// Tools are ordered by failure count, largest first.
pub fn Report::to_json(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
) -> String {
  let tools : Array[(Tool, Failures)] = self.tools.iter().collect()

  Json::object({
    "days": @jsonreport.number(days),
    "records": @jsonreport.number(records.to_int64()),
    "total": failures_json([], self.total),
    "tools": @jsonreport.top(
      tools,
      limit,
      entry => entry.1.failures.to_int64(),
      entry => {
        let (tool, failures) = entry
        failures_json(
          [
            ("tool", Json::string(tool.name)),
            ("command", Json::string(tool.command)),
          ],
          failures,
        )
      },
    ),
  }).stringify() +
  "\n"
}

///|
fn failures_json(keys : Array[(String, Json)], failures : Failures) -> Json {
  @jsonreport.object(
    keys +
    [
      ("failures", @jsonreport.number(failures.failures.to_int64())),
      ("repeats", @jsonreport.number(failures.repeats.to_int64())),
      ("sidechain_failures", @jsonreport.number(failures.sidechain.to_int64())),
      ("sessions", @jsonreport.number(failures.sessions.length().to_int64())),
    ],
  )
}
