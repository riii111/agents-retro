///|
/// Hook and user refusals belong to the hooks and interrupts reports.
fn is_rejection(text : String) -> Bool {
  is_hook_rejection(text) || is_user_rejection(text)
}

///|
fn is_hook_rejection(text : String) -> Bool {
  guard text.find(" hook error:") is Some(i) else { return false }

  let source = text[:i].to_owned()
  !source.is_empty() && !source.contains("\n") && !source.contains(" ")
}

///|
fn is_user_rejection(text : String) -> Bool {
  text.has_prefix("The user doesn't want to") ||
  text.has_prefix("The user declined ") ||
  text.has_prefix("[Request interrupted by user")
}
