

pub struct CompoundStmt {
  items: Array[Either[Statement, Declaration]]
  tokens: ArrayView[Token]
}

pub impl Eq for CompoundStmt with equal(self, other) {
  self.items == other.items
}

///|
pub fn Context::parse_compound_statement(
  self: Self,
  tokens: ArrayView[Token]
) -> (CompoundStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  guard tokens is [{kind: Bracket('{'), ..}, ..tokens] else {
    raise ParseError(tokens[0], "Expected '{' to start a compound statement")
  }
  let items: Array[Either[Statement, Declaration]] = Array::new()
  let rest = loop tokens {
    [{ kind: Bracket('}'), ..}, ..rest] => {
      break rest
    }
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
  let tokens = init_tokens[0:rest.start_offset() - start_offset]
  let compound_stmt = CompoundStmt::{
    items,
    tokens
  }
  (compound_stmt, rest)
}
