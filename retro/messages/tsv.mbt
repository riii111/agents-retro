///|
/// Files other than `messages.tsv` carry only a head and tail of each message so that reading them costs a bounded amount of context.
let preview_head = 140

///|
let preview_tail = 60

///|
pub fn message_tsv_line(m : Message) -> String {
  [
    m.id.to_string(),
    take_chars(m.ts, 16),
    m.app,
    m.role,
    m.session,
    m.cwd,
    flatten(m.text),
  ].join("\t")
}

///|
pub fn example_tsv_line(name : String, m : Message) -> String {
  [name, m.id.to_string(), m.session, preview(m.text)].join("\t")
}

///|
pub fn unmatched_tsv_line(m : Message) -> String {
  [m.id.to_string(), preview(m.text)].join("\t")
}

///|
fn preview(text : String) -> String {
  let flat = flatten(text)
  let length = flat.char_length()
  if length <= preview_head + preview_tail {
    return flat
  }

  "\{take_chars(flat, preview_head)} …[\{length}字]… \{take_last_chars(flat, preview_tail)}"
}
