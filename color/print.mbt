
pub fn taint_red(msg: String) -> String {
  return "\x1b[31m\{msg}\x1b[0m";
}

pub fn taint_yellow(msg: String) -> String {
  return "\x1b[33m\{msg}\x1b[0m";
}

pub fn taint_magenta(msg: String) -> String {
  return "\x1b[35m\{msg}\x1b[0m";
}
