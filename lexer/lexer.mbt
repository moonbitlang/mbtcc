
pub struct Context {
  code: String
  source_file: String
  err_toks: Array[Token]
}

pub fn Context::new(code~: String, source_file~: String) -> Context {
  Context::{
    code,
    source_file,
    err_toks: Array::new()
  }
}

pub fn Context::tokenize(self: Self) -> Array[Token] {
  let code = self.code[:]
  let tokens: Array[Token] = Array::new()
  let mut line = 1
  let mut col = 1
  let mut idx = 0
  loop code {
    [] => {
      tokens.push(Token::new(TokenKind::EOF, line, col, idx, ""))
      break
    }
    [.."##", .. rest] => {
      tokens.push(Token::new(TokenKind::Hash2, line, col, idx, "##"))
      idx += 2
      col += 2
      continue rest
    }
    [.."#", ..rest] => {
      tokens.push(Token::new(TokenKind::Hash, line, col, idx, "#"))
      idx += 1
      col += 1
      continue rest
    }
    ['\n', ..rest] => {
      line += 1
      col = 1
      idx += 1
      continue rest
    }
    [' '| '\t'| '\r', ..rest] => {
      idx += 1
      col += 1
      continue rest
    }
    [.."//", ..rest] => {
      // Single line comment
      loop rest {
        ['\n', ..rest2] => {
          line += 1
          col = 1
          idx += 1
          continue rest2
        }
        [_ , ..rest2] => {
          idx += 1
          col += 1
          continue rest2
        }
        [] => break
      }
    }
    [.."/*", ..rest] => {
      // Multi-line comment
      loop rest {
        [.."*/", ..rest2] => {
          idx += 2
          col += 2
          continue rest2
        }
        ['\n', ..rest2] => {
          line += 1
          col = 1
          idx += 1
          continue rest2
        }
        [_ , ..rest2] => {
          idx += 1
          col += 1
          continue rest2
        }
        [] => break
      }
    }
    [.."<<=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("<<="), line, col, idx, "<<="))
      idx += 3
      col += 3
      continue rest
    }
    [..">>=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator(">>="), line, col, idx, ">>="))
      idx += 3
      col += 3
      continue rest
    }
    [.."&&=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("&&="), line, col, idx, "&&="))
      idx += 3
      col += 3
      continue rest
    }
    [.."||=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("||="), line, col, idx, "||="))
      idx += 3
      col += 3
      continue rest
    }
    [.."...", ..rest] => {
      tokens.push(Token::new(TokenKind::Ellipsis, line, col, idx, "..."))
      idx += 3
      col += 3
      continue rest
    }
    [.."&&", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("&&"), line, col, idx, "&&"))
      idx += 2
      col += 2
      continue rest
    }
    [.."||", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("||"), line, col, idx, "||"))
      idx += 2
      col += 2
      continue rest
    }
    [.."<<", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("<<"), line, col, idx, "<<"))
      idx += 2
      col += 2
      continue rest
    }
    [..">>", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator(">>"), line, col, idx, ">>"))
      idx += 2
      col += 2
      continue rest
    }
    [.."++", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("++"), line, col, idx, "++"))
      idx += 2
      col += 2
      continue rest
    }
    [.."--", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("--"), line, col, idx, "--"))
      idx += 2
      col += 2
      continue rest
    }
    [.."->", ..rest] => {
      tokens.push(Token::new(TokenKind::Arrow, line, col, idx, "->"))
      idx += 2
      col += 2
      continue rest
    }
    [.."+=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("+="), line, col, idx, "+="))
      idx += 2
      col += 2
      continue rest
    }
    [.."-=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("-="), line, col, idx, "-="))
      idx += 2
      col += 2
      continue rest
    }
    [.."*=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("*="), line, col, idx, "*="))
      idx += 2
      col += 2
      continue rest
    }
    [.."/=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("/="), line, col, idx, "/="))
      idx += 2
      col += 2
      continue rest
    }
    [.."%=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("%="), line, col, idx, "%="))
      idx += 2
      col += 2
      continue rest
    }
    [.."&=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("&="), line, col, idx, "&="))
      idx += 2
      col += 2
      continue rest
    }
    [.."|=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("|="), line, col, idx, "|="))
      idx += 2
      col += 2
      continue rest
    }
    [.."^=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("^="), line, col, idx, "^="))
      idx += 2
      col += 2
      continue rest
    }
    [.."==", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("=="), line, col, idx, "=="))
      idx += 2
      col += 2
      continue rest
    }
    [.."!=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("!="), line, col, idx, "!="))
      idx += 2
      col += 2
      continue rest
    }
    [..">=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator(">="), line, col, idx, ">="))
      idx += 2
      col += 2
      continue rest
    }
    [.."<=", ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("<="), line, col, idx, "<="))
      idx += 2
      col += 2
      continue rest
    }
    ['(', ..rest] => {
      tokens.push(Token::new(TokenKind::Bracket('('), line, col, idx, "("))
      idx += 1
      col += 1
      continue rest
    }
    [')', ..rest] => {
      tokens.push(Token::new(TokenKind::Bracket(')'), line, col, idx, ")"))
      idx += 1
      col += 1
      continue rest
    }
    ['[', ..rest] => {
      tokens.push(Token::new(TokenKind::Bracket('['), line, col, idx, "["))
      idx += 1
      col += 1
      continue rest
    }
    [']', ..rest] => {
      tokens.push(Token::new(TokenKind::Bracket(']'), line, col, idx, "]"))
      idx += 1
      col += 1
      continue rest
    }
    ['{', ..rest] => {
      tokens.push(Token::new(TokenKind::Bracket('{'), line, col, idx, "{"))
      idx += 1
      col += 1
      continue rest
    }
    ['}', ..rest] => {
      tokens.push(Token::new(TokenKind::Bracket('}'), line, col, idx, "}"))
      idx += 1
      col += 1
      continue rest
    }
    [';', ..rest] => {
      tokens.push(Token::new(TokenKind::Semi, line, col, idx, ";"))
      idx += 1
      col += 1
      continue rest
    }
    [',', ..rest] => {
      tokens.push(Token::new(TokenKind::Comma, line, col, idx, ","))
      idx += 1
      col += 1
      continue rest
    }
    ['.', ..rest] => {
      tokens.push(Token::new(TokenKind::Dot, line, col, idx, "."))
      idx += 1
      col += 1
      continue rest
    }
    ['?', ..rest] => {
      tokens.push(Token::new(TokenKind::Question, line, col, idx, "?"))
      idx += 1
      col += 1
      continue rest
    }
    [':', ..rest] => {
      tokens.push(Token::new(TokenKind::Colon, line, col, idx, ":"))
      idx += 1
      col += 1
      continue rest
    }
    ['+', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("+"), line, col, idx, "+"))
      idx += 1
      col += 1
      continue rest
    }
    ['-', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("-"), line, col, idx, "-"))
      idx += 1
      col += 1
      continue rest
    }
    ['*', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("*"), line, col, idx, "*"))
      idx += 1
      col += 1
      continue rest
    }
    ['/', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("/"), line, col, idx, "/"))
      idx += 1
      col += 1
      continue rest
    }
    ['%', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("%"), line, col, idx, "%"))
      idx += 1
      col += 1
      continue rest
    }
    ['|', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("|"), line, col, idx, "|"))
      idx += 1
      col += 1
      continue rest
    }
    ['&', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("&"), line, col, idx, "&"))
      idx += 1
      col += 1
      continue rest
    }
    ['^', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("^"), line, col, idx, "^"))
      idx += 1
      col += 1
      continue rest
    }
    ['~', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("~"), line, col, idx, "~"))
      idx += 1
      col += 1
      continue rest
    }
    ['=', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("="), line, col, idx, "="))
      idx += 1
      col += 1
      continue rest
    }
    ['<', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("<"), line, col, idx, "<"))
      idx += 1
      col += 1
      continue rest
    }
    ['>', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator(">"), line, col, idx, ">"))
      idx += 1
      col += 1
      continue rest
    }
    ['!', ..rest] => {
      tokens.push(Token::new(TokenKind::Operator("!"), line, col, idx, "!"))
      idx += 1
      col += 1
      continue rest
    }
    ['"', ..] as code => {
      let (token, rest) = self.lex_string_literal(code, line, col, idx)
      tokens.push(token)
      let token_len = token.raw.length()
      idx += token_len
      col += token_len
      continue rest
    }
    ['\'', ..] as code => {
      let (token, rest) = self.lex_char_literal(code, line, col, idx)
      tokens.push(token)
      let token_len = token.raw.length()
      idx += token_len
      col += token_len
      continue rest
    }
    ['0'..='9', ..] as code => {
      let (token, rest) = self.lex_number_literal(code, line, col, idx)
      tokens.push(token)
      let token_len = token.raw.length()
      idx += token_len
      col += token_len
      continue rest
    }
    ['a'..='z' | 'A'..='Z' | '_' | '$', ..] as code => {
      let (token, rest) = self.lex_identifier_or_keyword(code, line, col, idx)
      tokens.push(token)
      let token_len = token.raw.length()
      idx += token_len
      col += token_len
      continue rest
    }
    [c, ..rest] => {
      let token_kind = TokenKind::ErrorChar(c)
      let err_msg = "Invalid character literal \{c}"
      let token = Token::new(token_kind, line, col, idx, "\{c}", err_msg~)
      tokens.push(token)
      self.err_toks.push(token)
      idx += 1
      col += 1
      continue rest
    }
  }
  tokens
}

fn Context::lex_string_literal(
  self: Self, code: StringView, line: Int, col: Int, idx: Int
) -> (Token, StringView) {
  guard code is ['"', .. code]  // skip first '"'
  let mut err_msg = ""
  let raw_str_builder = StringBuilder::new()
  let str_builder = StringBuilder::new()
  let rest = loop code {
    ['"', ..rest_str] => {
      raw_str_builder.write_char('"')
      break rest_str
    }
    [.."\\0", ..rest_str] => {
      raw_str_builder.write_char('\u0000')
      str_builder.write_char('\u0000')
      continue rest_str
    }
    [.."\\n", ..rest_str] => {
      raw_str_builder.write_char('\n')
      str_builder.write_char('\n')
      continue rest_str
    }
    [.."\\t", ..rest_str] => {
      raw_str_builder.write_char('\t')
      str_builder.write_char('\t')
      continue rest_str
    }
    [.."\\r", ..rest_str] => {
      raw_str_builder.write_char('\r')
      str_builder.write_char('\r')
      continue rest_str
    }
    [.."\\\"", ..rest_str] => {
      raw_str_builder.write_char('"')
      str_builder.write_char('"')
      continue rest_str
    }
    [.."\\\\", ..rest_str] => {
      raw_str_builder.write_char('\\')
      str_builder.write_char('\\')
      continue rest_str
    }
    ['\n', ..rest_str] => {
      err_msg = "Unterminated string literal"
      break rest_str // Unterminated string literal
    }
    [c, ..rest_str] => {
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
  raw_str_builder.write_string(str) // exclude surrounding quotes
  let toeken_kind = TokenKind::StringLit(str) // remove surrounding quotes
  let raw_str = raw_str_builder.to_string()
  let token = Token::new(toeken_kind, line, col, idx, raw_str, err_msg~)
  if !err_msg.is_empty() {
    self.err_toks.push(token)
  }
  (token, rest)
}

fn Context::lex_char_literal(
  self: Self, code: StringView, line: Int, col: Int, idx: Int
) -> (Token, StringView) {
  let raw_str_builder = StringBuilder::new()
  guard code is ['\'', .. code]  // skip first '\''
  raw_str_builder.write_char('\'')
  let mut err_msg = ""
  let (token_kind, rest) = match code {
    [.."\\0", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\0'")
      (TokenKind::CharLit('\u0000'), rest_str)
    }
    [.."\\n", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\n'")
      (TokenKind::CharLit('\n'), rest_str)
    }
    [.."\\r", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\r'")
      (TokenKind::CharLit('\r'), rest_str)
    }
    [.."\\t", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\t'")
      (TokenKind::CharLit('\t'), rest_str)
    }
    [.."\\\'", '\'', .. rest_str] => {
      raw_str_builder.write_string("\\\''")
      (TokenKind::CharLit('\''), rest_str)
    }
    [c, '\'', .. rest_str] => {
      raw_str_builder.write_char(c)
      raw_str_builder.write_char('\'')
      (TokenKind::CharLit(c), rest_str)
    }
    ['\'', ..rest_str] => {
      raw_str_builder.write_char('\'')
      err_msg = "Empty char literal"
      (TokenKind::CharLit('\u0000'), rest_str)
    }
    [c, ..rest_str] => {
      raw_str_builder.write_char(c)
      err_msg = "Unterminated char literal"
      (TokenKind::CharLit('\u0000'), rest_str)
    }
    [] as rest_str => {
      err_msg = "Unterminated char literal"
      (TokenKind::CharLit('\u0000'), rest_str)
    }
  }
  let raw_str = raw_str_builder.to_string()
  let token = Token::new(token_kind, line, col, idx, raw_str, err_msg~)
  if !err_msg.is_empty() {
    self.err_toks.push(token)
  }
  (token, rest)
}

fn Context::lex_number_literal(
  self: Self, code: StringView, line: Int, col: Int, idx: Int
) -> (Token, StringView) {
  lexmatch code {
    // Case 1. Hexadecimal floating-point literal
    (("0[xX]([0-9a-fA-F]+\.?[0-9a-fA-F]*|\.[0-9a-fA-F]+)[pP][\+\-]?[0-9]+" as hf) ("[fFlL]?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(hf.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = match (try? @strconv.parse_double(hf)) {
        Ok(n) => (n, "")
        Err(_) => (0.0, "Invalid hexadecimal floating-point literal")
      }
      let token_kind = match s {
        "f" | "F" => TokenKind::FloatLit(number.to_float())
        _ => TokenKind::DoubleLit(number)
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 2-1. Decimal floating-point literal with decimal point
    (("([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)([eE][\+\-]?[0-9]+)?" as df_dot) ("[fFlL]?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(df_dot.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = match (try? @strconv.parse_double(df_dot)) {
        Ok(n) => (n, "")
        Err(_) => (0.0, "Invalid decimal floating-point literal")
      }
      let token_kind = match s {
        "f" | "F" => TokenKind::FloatLit(number.to_float())
        _ => TokenKind::DoubleLit(number)
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 2-2: Decimal floating-point literal with exponent
    (("[0-9]+[eE][\+\-]?[0-9]+" as df_exp) ("[fFlL]?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(df_exp.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = match (try? @strconv.parse_double(df_exp)) {
        Ok(n) => (n, "")
        Err(_) => (0.0, "Invalid decimal floating-point literal")
      }
      let token_kind = match s {
        "f" | "F" => TokenKind::FloatLit(number.to_float())
        _ => TokenKind::DoubleLit(number)
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    } 
    // Case 3. Hexadecimal integer literal
    (("0[xX][0-9a-fA-F]+" as h) ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(h.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = match (try? @strconv.parse_uint(h, base=16)) {
        Ok(n) => (n, "")
        Err(_) => (0, "Invalid hexadecimal integer literal")
      }
      let token_kind = match s.to_lower() {
        "ull" | "llu" => TokenKind::ULongLit(number.to_uint64())
        "ul" | "lu" | "u" => TokenKind::UIntLit(number)
        "ll" | "l" => TokenKind::LongLit(number.to_int64())
        _ => TokenKind::IntLit(number.reinterpret_as_int())
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 4. Octal integer literal
    (("0[0-7]+" as o) ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(o.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = match (try? @strconv.parse_uint(o, base=8)) {
        Ok(n) => (n, "")
        Err(_) => (0, "Invalid octal integer literal")
      }
      let token_kind = match s.to_lower() {
        "ull" | "llu" => TokenKind::ULongLit(number.to_uint64())
        "ul" | "lu" | "u" => TokenKind::UIntLit(number)
        "ll" | "l" => TokenKind::LongLit(number.to_int64())
        _ => TokenKind::IntLit(number.reinterpret_as_int())
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 5. Decimal integer literal
    (("([1-9][0-9]*|0)" as d) ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(d.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = match (try? @strconv.parse_uint(d, base=10)) {
        Ok(n) => (n, "")
        Err(_) => (0, "Invalid decimal integer literal")
      }
      let token_kind = match s.to_lower() {
        "ull" | "llu" => TokenKind::ULongLit(number.to_uint64())
        "ul" | "lu" | "u" => TokenKind::UIntLit(number)
        "ll" | "l" => TokenKind::LongLit(number.to_int64())
        _ => TokenKind::IntLit(number.reinterpret_as_int())
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    _ => { abort("") }
  }
}

fn Context::lex_identifier_or_keyword(
  self: Self, code: StringView, line: Int, col: Int, idx: Int
) -> (Token, StringView) {
  ignore(self)
  lexmatch code {
    (("[a-zA-Z_$][a-zA-Z0-9_$]*" as ident), rest) => {
      let raw_str = ident.to_string()
      let token_kind = match keywords.get(ident.to_string()) {
        Some(kw) => TokenKind::Keyword(kw)
        None => TokenKind::Identifier(ident.to_string())
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      (token, rest)
    }
    _ => { abort("") }
  }
}
