///|
pub struct CompoundStmt {
  items : Array[Either[Statement, Declaration]]
  tokens : ArrayView[Token]
}

///|
pub impl Eq for CompoundStmt with equal(self, other) {
  self.items == other.items
}

///|
pub impl Show for CompoundStmt with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn CompoundStmt::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = if color {
    @color.taint("compound statement", Magenta)
  } else {
    "compound statement"
  }
  if self.items.length() == 0 {
    return prefix
  }
  let mut result = prefix
  for i, item in self.items {
    let item_str = match item {
      Left(stmt) => stmt.to_string(color~)
      Right(decl) => decl.to_string(color~)
    }
    let item_lines = item_str.split("\n")
    let is_last = i == self.items.length() - 1
    let item_formatted = if is_last {
      let head_with = "└-[\{i}]: "
      let continue_with = " ".repeat(head_with.length())
      format_lines(item_lines, head_with~, continue_with~)
    } else {
      let head_with = "├-[\{i}]: "
      let continue_with = "|" + " ".repeat(head_with.length() - 1)
      format_lines(item_lines, head_with~, continue_with~)
    }
    result = result + "\n" + item_formatted
  }
  result
}

///|
pub fn Context::parse_compound_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (CompoundStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  guard tokens is [{ kind: Bracket('{'), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected '{' to start a compound statement")
  }
  self.push_scope()
  let items : Array[Either[Statement, Declaration]] = Array::new()
  let rest = loop tokens {
    [{ kind: Bracket('}'), .. }, .. rest] => break rest
    [tok, ..] as tokens if self.is_type_tok(tok) => {
      let (decls, rest) = self.parse_declaration(tokens)
      decls.each(decl => items.push(Right(decl)))
      continue rest
    }
    tokens => {
      let (stmt, rest) = self.parse_statement(tokens)
      items.push(Either::Left(stmt))
      continue rest
    }
  }
  self.pop_scope()
  let tokens = init_tokens[0:rest.start_offset() - start_offset]
  let compound_stmt = CompoundStmt::{ items, tokens }
  (compound_stmt, rest)
}
