
pub struct ForStmt {

} derive(Eq)

pub fn Context::parse_for_statement(
  self: Self,
  tokens: ArrayView[Token]
) -> (ForStmt, ArrayView[Token]) raise ParseError {
  ignore(self)
  ignore(tokens)
  raise ParseError(tokens[0], "For Stmt Parsing Not implemented yet")
}
