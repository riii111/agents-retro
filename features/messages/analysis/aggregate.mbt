///|
struct PatternCount {
  name : String
  messages : Int32
  sessions : Int32
}

///|
/// A pattern under trial. It is counted apart from the formal patterns, so it never changes their counts or the unmatched messages.
struct CandidateCount {
  name : String
  messages : Int32
  sessions : Int32
  outside_patterns : Int32
  first_seen : String
  seen_before : Bool
}

///|
let examples_per_pattern = 3

///|
let unmatched_chunk_rows = 100

///|
pub fn count_patterns(hits : Array[PatternHits]) -> Array[PatternCount] {
  hits.map(h => {
    name: h.name,
    messages: h.messages.length(),
    sessions: session_count(h.messages),
  })
}

///|
/// `outside_patterns` counts the messages no formal pattern matched, which is what adopting the candidate would newly cover.
/// `first_seen` carries over from the previous run so a candidate tracked for weeks is not presented as new.
pub fn count_candidates(
  candidates : Array[PatternHits],
  formal : Array[PatternHits],
  previous : PreviousMetrics?,
  today~ : String,
) -> Array[CandidateCount] {
  let matched = matched_ids(formal)
  candidates.map(h => {
    let before = previous.bind(p => p.candidates.get(h.name))
    let first_seen = match before {
      Some(before) => before.first_seen
      None => today
    }

    {
      name: h.name,
      messages: h.messages.length(),
      sessions: session_count(h.messages),
      outside_patterns: h.messages.filter(m => !matched.contains(m.id)).length(),
      first_seen,
      seen_before: before is Some(_),
    }
  })
}

///|
/// Takes examples from distinct sessions so one long conversation cannot dominate.
pub fn pattern_examples(hits : Array[PatternHits]) -> Array[(String, Message)] {
  let examples = []
  for h in hits {
    let seen : Set[(String, String)] = Set([])
    for m in h.messages {
      if seen.length() == examples_per_pattern {
        break
      }
      if seen.contains(session_key(m)) {
        continue
      }

      seen.add(session_key(m))
      examples.push((h.name, m))
    }
  }

  examples
}

///|
pub fn unmatched_chunks(
  messages : Array[Message],
  hits : Array[PatternHits],
) -> Array[Array[Message]] {
  let matched = matched_ids(hits)
  let unmatched = messages.filter(m => !matched.contains(m.id))
  let chunks = []
  for start = 0
      start < unmatched.length()
      start = start + unmatched_chunk_rows {
    let end = if start + unmatched_chunk_rows < unmatched.length() {
      start + unmatched_chunk_rows
    } else {
      unmatched.length()
    }
    chunks.push(unmatched[start:end].to_owned())
  }

  chunks
}

///|
fn matched_ids(hits : Array[PatternHits]) -> Set[Int32] {
  let matched : Set[Int32] = Set([])
  for h in hits {
    for m in h.messages {
      matched.add(m.id)
    }
  }

  matched
}

///|
pub fn session_count(messages : Array[Message]) -> Int32 {
  Set::from_iter(messages.iter().map(session_key)).length()
}

///|
/// Message counts per `app/role`, sorted by key.
pub fn count_by_role(messages : Array[Message]) -> Array[(String, Int32)] {
  let counts : Map[String, Int32] = Map([])
  for m in messages {
    let key = "\{m.app}/\{m.role}"
    counts[key] = counts.get_or_default(key, 0) + 1
  }

  let keys = counts.keys().collect()
  keys.sort_by((a, b) => a.lexical_compare(b))
  keys.map(k => (k, counts[k]))
}

///|
fn session_key(m : Message) -> (String, String) {
  (m.app, m.session)
}
