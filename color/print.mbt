
pub(all) enum Color {
  Red
  Yellow
  Magenta
}

pub fn taint(msg: String, color: Color) -> String {
  match color {
    Red => "\x1b[31m\{msg}\x1b[0m"
    Yellow => "\x1b[33m\{msg}\x1b[0m"
    Magenta => "\x1b[35m\{msg}\x1b[0m"
  }
}
