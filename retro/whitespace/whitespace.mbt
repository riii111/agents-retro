///|
/// Unicode whitespace plus the U+001C–U+001F control separators.
pub fn is_space(c : Char) -> Bool {
  match c {
    '\t' | '\n' | '\u{0b}' | '\u{0c}' | '\r' | ' ' => true
    '\u{1c}'..<='\u{1f}' | '\u{85}' | '\u{a0}' | '\u{1680}' => true
    '\u{2000}'..<='\u{200a}' | '\u{2028}' | '\u{2029}' | '\u{202f}' => true
    '\u{205f}' | '\u{3000}' => true
    _ => false
  }
}
