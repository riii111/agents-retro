///|
pub fn options() -> Array[@argparse.OptionArg] {
  [
    OptionArg("days", long="days", default_values=["7"]),
    OptionArg(
      "patterns",
      long="patterns",
      about="JSON object of category name to regex; required for message reports",
    ),
    OptionArg("out-dir", long="out-dir", about="Required for message reports"),
  ]
}

///|
fn paths(matches : @argparse.Matches) -> (String, String) raise {
  guard matches.values.get("patterns") is Some([patterns, ..]) else {
    fail("--patterns is required for message reports")
  }
  guard matches.values.get("out-dir") is Some([out_dir, ..]) else {
    fail("--out-dir is required for message reports")
  }

  (patterns, out_dir)
}
