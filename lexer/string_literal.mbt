///|
fn Context::lex_string_literal(
  self : Self,
  code : StringView,
  source_file : String,
  line : Int,
  col : Int,
  idx : Int,
) -> (Token, StringView) {
  guard code is ['"', .. code]  // skip first '"'
  let mut err_msg = ""
  let raw_str_builder = StringBuilder::new()
  let str_builder = StringBuilder::new()
  // Preserve original token spelling in `raw` (including surrounding quotes and escapes),
  // while storing the decoded string value in `TokenKind::String`.
  raw_str_builder.write_char('"')
  let rest = loop code {
    ['"', .. rest_str] => {
      raw_str_builder.write_char('"')
      break rest_str
    }
    [.. "\\0", .. rest_str] => {
      raw_str_builder.write_string("\\0")
      str_builder.write_char('\u0000')
      continue rest_str
    }
    [.. "\\n", .. rest_str] => {
      raw_str_builder.write_string("\\n")
      str_builder.write_char('\n')
      continue rest_str
    }
    [.. "\\t", .. rest_str] => {
      raw_str_builder.write_string("\\t")
      str_builder.write_char('\t')
      continue rest_str
    }
    [.. "\\r", .. rest_str] => {
      raw_str_builder.write_string("\\r")
      str_builder.write_char('\r')
      continue rest_str
    }
    [.. "\\\"", .. rest_str] => {
      raw_str_builder.write_string("\\\"")
      str_builder.write_char('"')
      continue rest_str
    }
    [.. "\\\\", .. rest_str] => {
      raw_str_builder.write_string("\\\\")
      str_builder.write_char('\\')
      continue rest_str
    }
    [.. "\\\'", .. rest_str] => {
      raw_str_builder.write_string("\\\'")
      str_builder.write_char('\'')
      continue rest_str
    }
    ['\n', .. rest_str] => {
      err_msg = "Unterminated string literal"
      break rest_str // Unterminated string literal
    }
    [c, .. rest_str] => {
      raw_str_builder.write_char(c)
      str_builder.write_char(c)
      continue rest_str
    }
    [] as code => {
      err_msg = "Unterminated string literal"
      break code // Unterminated string literal
    }
  }
  let str = str_builder.to_string()
  let toeken_kind = TokenKind::String(str) // remove surrounding quotes
  let raw_str = raw_str_builder.to_string()
  let token = Token::new(
    toeken_kind,
    source_file,
    line,
    col,
    idx,
    raw_str,
    err_msg~,
  )
  if !err_msg.is_empty() {
    self.err_toks.push(token)
  }
  (token, rest)
}

///|
fn Context::lex_char_literal(
  self : Self,
  code : StringView,
  source_file : String,
  line : Int,
  col : Int,
  idx : Int,
) -> (Token, StringView) {
  let raw_str_builder = StringBuilder::new()
  guard code is ['\'', .. code]  // skip first '\''
  raw_str_builder.write_char('\'')
  let mut err_msg = ""
  let (token_kind, rest) = match code {
    [.. "\\0", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\0'")
      (TokenKind::Char('\u0000'), rest_str)
    }
    [.. "\\n", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\n'")
      (TokenKind::Char('\n'), rest_str)
    }
    [.. "\\r", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\r'")
      (TokenKind::Char('\r'), rest_str)
    }
    [.. "\\t", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\t'")
      (TokenKind::Char('\t'), rest_str)
    }
    [.. "\\\'", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\\''")
      (TokenKind::Char('\''), rest_str)
    }
    [.. "\\\\", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\\\'")
      (TokenKind::Char('\\'), rest_str)
    }
    [c, '\'', .. rest_str] => {
      raw_str_builder.write_char(c)
      raw_str_builder.write_char('\'')
      (TokenKind::Char(c), rest_str)
    }
    ['\'', .. rest_str] => {
      raw_str_builder.write_char('\'')
      err_msg = "Empty char literal"
      (TokenKind::Char('\u0000'), rest_str)
    }
    [c, .. rest_str] => {
      raw_str_builder.write_char(c)
      err_msg = "Unterminated char literal"
      (TokenKind::Char('\u0000'), rest_str)
    }
    [] as rest_str => {
      err_msg = "Unterminated char literal"
      (TokenKind::Char('\u0000'), rest_str)
    }
  }
  let raw_str = raw_str_builder.to_string()
  let token = Token::new(
    token_kind,
    source_file,
    line,
    col,
    idx,
    raw_str,
    err_msg~,
  )
  if !err_msg.is_empty() {
    self.err_toks.push(token)
  }
  (token, rest)
}
