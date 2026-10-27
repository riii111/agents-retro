///|
async test "VERSION matches the version in moon.mod" {
  let manifest = find_module_manifest(@env.args()[0])
  assert_eq(VERSION, module_version(@fs.read_file(manifest).text()))
}

///|
/// The test binary is built under the module's `_build`, so the module root is
/// found from its path instead of the working directory.
async fn find_module_manifest(executable : String) -> String {
  let mut dir = @fs.realpath(executable)
  while true {
    guard dir.rev_find("/") is Some(index) && index > 0 else {
      fail("moon.mod not found above \{executable}")
    }
    dir = dir[:index].to_owned()
    let candidate = "\{dir}/moon.mod"
    if @fs.exists(candidate) {
      return candidate
    }
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
