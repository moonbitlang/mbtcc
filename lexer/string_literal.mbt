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
  fn is_hex_digit(c : Char) -> Bool {
    (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
  }
  fn is_octal_digit(c : Char) -> Bool { c >= '0' && c <= '7' }
  let rest = loop code {
    ['"', .. rest_str] => {
      raw_str_builder.write_char('"')
      break rest_str
    }
    [.. "\\x", .. rest_str] => {
      let mut hex = ""
      let rest2 = loop rest_str {
        [c, .. r] if is_hex_digit(c) => {
          hex = hex + c.to_string()
          continue r
        }
        rest => break rest
      }
      if hex.length() == 0 {
        raw_str_builder.write_string("\\x")
        str_builder.write_char('x')
        continue rest2
      }
      let val = @strconv.parse_int(hex, base=16) catch { _ => 0 }
      raw_str_builder.write_string("\\x" + hex)
      str_builder.write_char(val.unsafe_to_char())
      continue rest2
    }
    [.. "\\", c, .. rest_str] if is_octal_digit(c) => {
      let mut oct = c.to_string()
      let mut count = 1
      let rest2 = loop rest_str {
        [c2, .. r] if is_octal_digit(c2) && count < 3 => {
          oct = oct + c2.to_string()
          count = count + 1
          continue r
        }
        rest => break rest
      }
      let val = @strconv.parse_int(oct, base=8) catch { _ => 0 }
      raw_str_builder.write_string("\\" + oct)
      str_builder.write_char(val.unsafe_to_char())
      continue rest2
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
  fn is_hex_digit(c : Char) -> Bool {
    (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
  }
  fn is_octal_digit(c : Char) -> Bool { c >= '0' && c <= '7' }
  let (token_kind, rest) = match code {
    [.. "\\x", .. rest_str] => {
      let mut hex = ""
      let rest2 = loop rest_str {
        [c, .. r] if is_hex_digit(c) => {
          hex = hex + c.to_string()
          continue r
        }
        rest => break rest
      }
      match rest2 {
        ['\'', .. rest3] => {
          if hex.length() == 0 {
            raw_str_builder.write_string("\\x'")
            (TokenKind::Char('x'), rest3)
          } else {
            let val = @strconv.parse_int(hex, base=16) catch { _ => 0 }
            raw_str_builder.write_string("\\x" + hex + "'")
            (TokenKind::Char(val.unsafe_to_char()), rest3)
          }
        }
        _ => {
          err_msg = "Unterminated char literal"
          (TokenKind::Char('\u0000'), rest2)
        }
      }
    }
    [.. "\\", c, .. rest_str] if is_octal_digit(c) => {
      let mut oct = c.to_string()
      let mut count = 1
      let rest2 = loop rest_str {
        [c2, .. r] if is_octal_digit(c2) && count < 3 => {
          oct = oct + c2.to_string()
          count = count + 1
          continue r
        }
        rest => break rest
      }
      match rest2 {
        ['\'', .. rest3] => {
          let val = @strconv.parse_int(oct, base=8) catch { _ => 0 }
          raw_str_builder.write_string("\\" + oct + "'")
          (TokenKind::Char(val.unsafe_to_char()), rest3)
        }
        _ => {
          err_msg = "Unterminated char literal"
          (TokenKind::Char('\u0000'), rest2)
        }
      }
    }
    [.. "\\0", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\0'")
      (TokenKind::Char('\u0000'), rest_str)
    }
    [.. "\\n", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\n'")
      (TokenKind::Char('\n'), rest_str)
    }
    [.. "\\v", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\v'")
      (TokenKind::Char('\u000b'), rest_str)
    }
    [.. "\\r", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\r'")
      (TokenKind::Char('\r'), rest_str)
    }
    [.. "\\t", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\t'")
      (TokenKind::Char('\t'), rest_str)
    }
    [.. "\\a", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\a'")
      (TokenKind::Char('\u0007'), rest_str)
    }
    [.. "\\b", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\b'")
      (TokenKind::Char('\u0008'), rest_str)
    }
    [.. "\\f", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\f'")
      (TokenKind::Char('\u000c'), rest_str)
    }
    [.. "\\\'", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\\''")
      (TokenKind::Char('\''), rest_str)
    }
    [.. "\\\"", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\\"'")
      (TokenKind::Char('\"'), rest_str)
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
