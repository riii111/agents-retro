///|
/// Used lists are ordered by invocations, largest first. `unused_skills` lists
/// every installed skill without a use and is not cut by `limit`.
pub fn Report::to_json(
  self : Report,
  days~ : Int64,
  records~ : Int32,
  limit~ : Int32,
  claude_skills~ : Array[String],
  codex_skills~ : Array[String],
) -> String {
  let installed : Set[String] = Set([])
  let unused = []
  for group in [("claude", claude_skills), ("codex", codex_skills)] {
    let (source, names) = group
    for name in names {
      let id = "\{source}/\{name}"
      installed.add(id)
      if !self.used.contains(id) {
        unused.push(
          Json::object({
            "source": Json::string(source),
            "skill": Json::string(name),
          }),
        )
      }
    }
  }

  let skills : Array[(SkillUse, Tally)] = self.skills.iter().collect()
  let subagents : Array[(SubagentUse, Tally)] = self.subagents.iter().collect()

  Json::object({
    "days": @jsonreport.number(days),
    "records": @jsonreport.number(records.to_int64()),
    "skills": @jsonreport.top(
      skills,
      limit,
      entry => entry.1.invocations.to_int64(),
      entry => {
        tally_json(
          [
            ("source", Json::string(entry.0.source)),
            ("skill", Json::string(entry.0.name)),
            ("via", Json::string(entry.0.via)),
            (
              "installed",
              Json::boolean(
                installed.contains(
                  "\{entry.0.source}/\{bare_name(entry.0.name)}",
                ),
              ),
            ),
          ],
          entry.1,
        )
      },
    ),
    "subagents": @jsonreport.top(
      subagents,
      limit,
      entry => entry.1.invocations.to_int64(),
      entry => {
        tally_json(
          [
            ("source", Json::string(entry.0.source)),
            ("subagent_type", Json::string(entry.0.subagent_type)),
          ],
          entry.1,
        )
      },
    ),
    "unused_skills": Json::array(unused),
  }).stringify() +
  "\n"
}

///|
fn tally_json(keys : Array[(String, Json)], tally : Tally) -> Json {
  @jsonreport.object(
    keys +
    [
      ("invocations", @jsonreport.number(tally.invocations.to_int64())),
      ("sidechain_invocations", @jsonreport.number(tally.sidechain.to_int64())),
      ("sessions", @jsonreport.number(tally.sessions.length().to_int64())),
    ],
  )
}
