///|
/// Tools are ordered by failure count, largest first.
pub fn Report::to_json(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
) -> String {
  let tools : Array[(Tool, Failures)] = self.tools.iter().collect()
  let ranked = tools.mapi((i, tool) => (tool, i))
  ranked.sort_by((a, b) => {
    let by_failures = b.0.1.failures.compare(a.0.1.failures)
    if by_failures == 0 {
      a.1.compare(b.1)
    } else {
      by_failures
    }
  })

  Json::object({
    "days": number(days),
    "records": number(records.to_int64()),
    "total": failures_json([], self.total),
    "tools": Json::array(
      ranked
      .iter()
      .take(limit)
      .map(entry => {
        let (tool, failures) = entry.0
        failures_json(
          [
            ("tool", Json::string(tool.name)),
            ("command", Json::string(tool.command)),
          ],
          failures,
        )
      })
      .collect(),
    ),
  }).stringify() +
  "\n"
}

///|
fn number(n : Int64) -> Json {
  Json::number(n.to_double())
}

///|
fn failures_json(keys : Array[(String, Json)], failures : Failures) -> Json {
  let fields : Map[String, Json] = Map([])
  for key in keys {
    fields[key.0] = key.1
  }

  fields["failures"] = number(failures.failures.to_int64())
  fields["repeats"] = number(failures.repeats.to_int64())
  fields["sidechain_failures"] = number(failures.sidechain.to_int64())
  fields["sessions"] = number(failures.sessions.length().to_int64())
  Json::object(fields)
}
