

pub struct IfStmt {

} derive(Eq)

pub fn Context::parse_if_statement(
  self: Self,
  tokens: ArrayView[Token]
) -> (IfStmt, ArrayView[Token]) raise ParseError {
  ignore(self)
  ignore(tokens)
  raise ParseError(tokens[0], "If Stmt parsing Not implemented yet")
}
