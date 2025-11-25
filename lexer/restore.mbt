
pub fn restore_code_from_tokens(tokens: Array[Token]) -> String {
  // tokens.each(tok => println(tok))
  if tokens.is_empty() {
    return ""
  }
  let sb = StringBuilder::new()
  let mut file_name = "\u{0000}"
  let mut tok_line = 1
  let mut tok_col = 1
  for tok in tokens {
    if tok.kind is EOF {
      continue
    }
    let { kind, line, col, raw, source_file, .. } = tok
    if source_file != file_name {
      tok_line = 1
      file_name = source_file
      sb.write_string("\n# \{file_name}\n")
    }
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
