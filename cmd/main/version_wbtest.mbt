///|
async test "VERSION matches the version in moon.mod" {
  guard @env.current_dir() is Some(cwd) else { fail("current dir is unknown") }
  let manifest = find_module_manifest(cwd)
  assert_eq(VERSION, module_version(@fs.read_file(manifest).text()))
}

///|
async fn find_module_manifest(start : String) -> String {
  let mut dir = start
  while true {
    let candidate = "\{dir}/moon.mod"
    if @fs.exists(candidate) {
      return candidate
    }
    guard dir.rev_find("/") is Some(index) && index > 0 else {
      fail("moon.mod not found above \{start}")
    }
    dir = dir[:index].to_owned()
  }
  fail("unreachable")
}

///|
fn module_version(manifest : String) -> String raise {
  for line in manifest.split("\n") {
    if line.strip_prefix("version = \"") is Some(rest) &&
      rest.strip_suffix("\"") is Some(version) {
      return version.to_owned()
    }
  }
  fail("version not found in moon.mod")
}
