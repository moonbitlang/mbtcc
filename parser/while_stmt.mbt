

pub struct WhileStmt {

} derive(Eq)

pub fn Context::parse_while_statement(
  self: Self,
  tokens: ArrayView[Token]
) -> (WhileStmt, ArrayView[Token]) raise ParseError {
  ignore(self)
  ignore(tokens)
  raise ParseError(tokens[0], "While Stmt Parsing Not implemented yet")
}
