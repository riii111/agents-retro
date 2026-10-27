///|
test "command_head skips control syntax reserved words" {
  for
    (command, head) in [
      ("for x in a b; do echo $x; done", "echo"),
      ("for x in a b\ndo\n  git status\ndone", "git status"),
      ("while true; do sleep 1; done", "true"),
      ("until test -f x; do sleep 1; done", "test"),
      ("if git diff --quiet; then echo clean; fi", "git diff"),
      ("if [ -f x ]; then cat x; else echo none; fi", "["),
      ("! grep -q x file", "grep"),
      ("{ ls; }", "ls"),
      ("select x in a; do echo $x; done", "echo"),
      ("for ((i=0; i<3; i++)); do echo $i; done", "echo"),
      ("for ((i=0; i<3; i++))\ndo\n  git status\ndone", "git status"),
      ("(( i++ )); ls", "ls"),
      ("echo $((1 + 2)); ls", "echo"),
      ("echo a \\\n  b; ls", "echo"),
      ("case $x in a) echo a;; esac", "echo"),
      (
        "case $x in\n  a|b) git status ;;\n  *) echo other ;;\nesac", "git status",
      ),
      ("case $x in\n  a)\n    ls\n    ;;\nesac", "ls"),
      ("case $x in a | b) FOO=1 make;; esac", "make"),
      ("case $x in a) ;; esac", ""),
      ("done", ""),
      ("fi", ""),
      ("for x in a b", ""),
    ] {
    assert_eq(command_head(command), head, msg=command)
  }
}

///|
test "command_head skips environment variable assignments" {
  for
    (command, head) in [
      ("FOO=bar make", "make"),
      ("A=1 B=2 cargo test", "cargo test"),
      ("_x1=y git status", "git status"),
      ("A=\"x y\" git status", "git status"),
      ("A='x y' B=z npm run check", "npm run"),
      ("A=\"x;y\" git status", "git status"),
      ("A=\"x && y\" git status", "git status"),
      ("A=\"x\ny\" git status", "git status"),
      ("A='x;y' B=\"1\\\";2\" cargo test", "cargo test"),
      ("env A=1 B=2 git log", "git log"),
      ("FOO=bar", ""),
      ("FOO=bar; ls", "ls"),
      ("echo a=b", "echo"),
      ("curl --data=x http://example.com", "curl"),
    ] {
    assert_eq(command_head(command), head, msg=command)
  }
}

///|
test "command_head keeps the first executed command of compound lines" {
  for
    (command, head) in [
      ("cd /repo && A=1 for x in a; do ls; done", "ls"),
      ("cd /repo && if true; then git status; fi", "true"),
      ("git -C \"/my repo\" status", "git status"),
      ("echo \"a b\" c", "echo"),
      ("", ""),
    ] {
    assert_eq(command_head(command), head, msg=command)
  }
}
