///|
/// Claude Code commands that are not skills. They are logged like a skill's `/<name>`.
let builtin_commands : Set[String] = Set([
  "add-dir", "agents", "clear", "compact", "config", "context", "cost", "doctor",
  "exit", "export", "fast", "help", "hooks", "ide", "login", "logout", "mcp", "memory",
  "model", "permissions", "plugin", "quit", "reload-plugins", "rename", "resume",
  "rewind", "sandbox", "status", "statusline", "terminal-setup", "theme", "usage",
  "vim",
])
