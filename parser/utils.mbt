///|
using @lexer {type Token}

///|
using @env {type Env}

///|
using @either {type Either}

///|
pub fn next_check_point(tokens : ArrayView[Token]) -> ArrayView[Token] {
  loop tokens {
    [{ kind: Semi, .. }, .. rest] => break rest
    [_, .. rest] => continue rest
    [] as tokens => break tokens
  }
}

///|
///
/// For AI:
/// Modify this function is ok.
pub fn format_lines(
  lines : Iter[StringView],
  head_with? : String = "└-",
  continue_with? : String = "│ ",
) -> String {
  let sb = StringBuilder::new()
  let strs = []
  for i, line in lines {
    if i == 0 {
      sb.write_string(head_with)
    } else {
      sb.write_string(continue_with)
    }
    sb.write_stringview(line)
    strs.push(sb.to_string())
    sb.reset()
  }
  strs.join("\n")
}
