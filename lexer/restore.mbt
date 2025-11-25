
pub fn restore_code_from_tokens(tokens: Array[Token]) -> String {
  // tokens.each(tok => println(tok.detail()))
  if tokens.is_empty() {
    return ""
  }
  let sb = StringBuilder::new()
  let mut tok_line = tokens[0].line
  let mut tok_col = 1
  for tok in tokens {
    let { kind, line, col, raw, .. } = tok
    if line != tok_line {
      let s = "\n".repeat(line - tok_line)
      let s = if s.is_empty() { "\n" } else { s }
      sb.write_string(s)
      tok_line = line
      tok_col = 1
    }
    let space = " ".repeat(col - tok_col)
    sb.write_string(space)
    tok_col = col + raw.length()
    sb.write_object(kind)
  }
  sb.to_string();
}

fn max(a: Int, b: Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
