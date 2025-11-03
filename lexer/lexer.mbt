///|
pub struct Context {
  code : String
  source_file : String
  tokens : Array[Token]
  err_toks : Array[Token]
}

///|
pub fn Context::new(code~ : String, source_file~ : String) -> Context {
  Context::{ code, source_file, tokens: Array::new(), err_toks: Array::new() }
}

///|
pub fn Context::tokenize(self : Self) -> Array[Token] {
  let code = self.code[:]
  let tokens : Array[Token] = self.tokens
  let mut line = 1
  let mut col = 1
  let mut idx = 0
  loop code {
    [] => {
      tokens.push(Token::new(EOF, line, col, idx, ""))
      break
    }
    [.. "##", .. rest] => {
      tokens.push(Token::new(Hash2, line, col, idx, "##"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "#", .. rest] => {
      tokens.push(Token::new(Hash, line, col, idx, "#"))
      idx += 1
      col += 1
      continue rest
    }
    ['\n', .. rest] => {
      line += 1
      col = 1
      idx += 1
      continue rest
    }
    [' ' | '\t' | '\r', .. rest] => {
      idx += 1
      col += 1
      continue rest
    }
    [.. "//", .. rest] =>
      // Single line comment
      loop rest {
        ['\n', .. rest2] => {
          line += 1
          col = 1
          idx += 1
          continue rest2
        }
        [_, .. rest2] => {
          idx += 1
          col += 1
          continue rest2
        }
        [] => break
      }
    [.. "/*", .. rest] =>
      // Multi-line comment
      loop rest {
        [.. "*/", .. rest2] => {
          idx += 2
          col += 2
          continue rest2
        }
        ['\n', .. rest2] => {
          line += 1
          col = 1
          idx += 1
          continue rest2
        }
        [_, .. rest2] => {
          idx += 1
          col += 1
          continue rest2
        }
        [] => break
      }
    [.. "<<=", .. rest] => {
      tokens.push(Token::new(Operator("<<="), line, col, idx, "<<="))
      idx += 3
      col += 3
      continue rest
    }
    [.. ">>=", .. rest] => {
      tokens.push(Token::new(Operator(">>="), line, col, idx, ">>="))
      idx += 3
      col += 3
      continue rest
    }
    [.. "&&=", .. rest] => {
      tokens.push(Token::new(Operator("&&="), line, col, idx, "&&="))
      idx += 3
      col += 3
      continue rest
    }
    [.. "||=", .. rest] => {
      tokens.push(Token::new(Operator("||="), line, col, idx, "||="))
      idx += 3
      col += 3
      continue rest
    }
    [.. "...", .. rest] => {
      tokens.push(Token::new(Ellipsis, line, col, idx, "..."))
      idx += 3
      col += 3
      continue rest
    }
    [.. "&&", .. rest] => {
      tokens.push(Token::new(Operator("&&"), line, col, idx, "&&"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "||", .. rest] => {
      tokens.push(Token::new(Operator("||"), line, col, idx, "||"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "<<", .. rest] => {
      tokens.push(Token::new(Operator("<<"), line, col, idx, "<<"))
      idx += 2
      col += 2
      continue rest
    }
    [.. ">>", .. rest] => {
      tokens.push(Token::new(Operator(">>"), line, col, idx, ">>"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "++", .. rest] => {
      tokens.push(Token::new(Operator("++"), line, col, idx, "++"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "--", .. rest] => {
      tokens.push(Token::new(Operator("--"), line, col, idx, "--"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "->", .. rest] => {
      tokens.push(Token::new(Arrow, line, col, idx, "->"))
      idx += 2
      col += 2
      continue rest
    }
    [.. "+=", .. rest] => {
      tokens.push(Token::new(Operator("+="), line, col, idx, "+="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "-=", .. rest] => {
      tokens.push(Token::new(Operator("-="), line, col, idx, "-="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "*=", .. rest] => {
      tokens.push(Token::new(Operator("*="), line, col, idx, "*="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "/=", .. rest] => {
      tokens.push(Token::new(Operator("/="), line, col, idx, "/="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "%=", .. rest] => {
      tokens.push(Token::new(Operator("%="), line, col, idx, "%="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "&=", .. rest] => {
      tokens.push(Token::new(Operator("&="), line, col, idx, "&="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "|=", .. rest] => {
      tokens.push(Token::new(Operator("|="), line, col, idx, "|="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "^=", .. rest] => {
      tokens.push(Token::new(Operator("^="), line, col, idx, "^="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "==", .. rest] => {
      tokens.push(Token::new(Operator("=="), line, col, idx, "=="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "!=", .. rest] => {
      tokens.push(Token::new(Operator("!="), line, col, idx, "!="))
      idx += 2
      col += 2
      continue rest
    }
    [.. ">=", .. rest] => {
      tokens.push(Token::new(Operator(">="), line, col, idx, ">="))
      idx += 2
      col += 2
      continue rest
    }
    [.. "<=", .. rest] => {
      tokens.push(Token::new(Operator("<="), line, col, idx, "<="))
      idx += 2
      col += 2
      continue rest
    }
    ['(', .. rest] => {
      tokens.push(Token::new(Bracket('('), line, col, idx, "("))
      idx += 1
      col += 1
      continue rest
    }
    [')', .. rest] => {
      tokens.push(Token::new(Bracket(')'), line, col, idx, ")"))
      idx += 1
      col += 1
      continue rest
    }
    ['[', .. rest] => {
      tokens.push(Token::new(Bracket('['), line, col, idx, "["))
      idx += 1
      col += 1
      continue rest
    }
    [']', .. rest] => {
      tokens.push(Token::new(Bracket(']'), line, col, idx, "]"))
      idx += 1
      col += 1
      continue rest
    }
    ['{', .. rest] => {
      tokens.push(Token::new(Bracket('{'), line, col, idx, "{"))
      idx += 1
      col += 1
      continue rest
    }
    ['}', .. rest] => {
      tokens.push(Token::new(Bracket('}'), line, col, idx, "}"))
      idx += 1
      col += 1
      continue rest
    }
    [';', .. rest] => {
      tokens.push(Token::new(Semi, line, col, idx, ";"))
      idx += 1
      col += 1
      continue rest
    }
    [',', .. rest] => {
      tokens.push(Token::new(Comma, line, col, idx, ","))
      idx += 1
      col += 1
      continue rest
    }
    ['.', .. rest] => {
      tokens.push(Token::new(Dot, line, col, idx, "."))
      idx += 1
      col += 1
      continue rest
    }
    ['?', .. rest] => {
      tokens.push(Token::new(Question, line, col, idx, "?"))
      idx += 1
      col += 1
      continue rest
    }
    [':', .. rest] => {
      tokens.push(Token::new(Colon, line, col, idx, ":"))
      idx += 1
      col += 1
      continue rest
    }
    ['+', .. rest] => {
      tokens.push(Token::new(Operator("+"), line, col, idx, "+"))
      idx += 1
      col += 1
      continue rest
    }
    ['-', .. rest] => {
      tokens.push(Token::new(Operator("-"), line, col, idx, "-"))
      idx += 1
      col += 1
      continue rest
    }
    ['*', .. rest] => {
      tokens.push(Token::new(Operator("*"), line, col, idx, "*"))
      idx += 1
      col += 1
      continue rest
    }
    ['/', .. rest] => {
      tokens.push(Token::new(Operator("/"), line, col, idx, "/"))
      idx += 1
      col += 1
      continue rest
    }
    ['%', .. rest] => {
      tokens.push(Token::new(Operator("%"), line, col, idx, "%"))
      idx += 1
      col += 1
      continue rest
    }
    ['|', .. rest] => {
      tokens.push(Token::new(Operator("|"), line, col, idx, "|"))
      idx += 1
      col += 1
      continue rest
    }
    ['&', .. rest] => {
      tokens.push(Token::new(Operator("&"), line, col, idx, "&"))
      idx += 1
      col += 1
      continue rest
    }
    ['^', .. rest] => {
      tokens.push(Token::new(Operator("^"), line, col, idx, "^"))
      idx += 1
      col += 1
      continue rest
    }
    ['~', .. rest] => {
      tokens.push(Token::new(Operator("~"), line, col, idx, "~"))
      idx += 1
      col += 1
      continue rest
    }
    ['=', .. rest] => {
      tokens.push(Token::new(Operator("="), line, col, idx, "="))
      idx += 1
      col += 1
      continue rest
    }
    ['<', .. rest] => {
      tokens.push(Token::new(Operator("<"), line, col, idx, "<"))
      idx += 1
      col += 1
      continue rest
    }
    ['>', .. rest] => {
      tokens.push(Token::new(Operator(">"), line, col, idx, ">"))
      idx += 1
      col += 1
      continue rest
    }
    ['!', .. rest] => {
      tokens.push(Token::new(Operator("!"), line, col, idx, "!"))
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
    [c, .. rest] => {
      let token_kind = ErrorChar(c)
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

///|
fn Context::lex_identifier_or_keyword(
  self : Self,
  code : StringView,
  line : Int,
  col : Int,
  idx : Int,
) -> (Token, StringView) {
  ignore(self)
  lexmatch code {
    ("[a-zA-Z_$][a-zA-Z0-9_$]*" as ident, rest) => {
      let raw_str = ident.to_string()
      let token_kind = match keywords.get(ident.to_string()) {
        Some(kw) => Keyword(kw)
        None => Identifier(ident.to_string())
      }
      let token = Token::new(token_kind, line, col, idx, raw_str)
      (token, rest)
    }
    _ => abort("")
  }
}
