

pub struct SwitchStmt {

} derive(Eq)

pub fn Context::parse_switch_statement(
  self: Self,
  tokens: ArrayView[Token]
) -> (SwitchStmt, ArrayView[Token]) raise ParseError {
  ignore(self)
  ignore(tokens)
  raise ParseError(tokens[0], "Switch Stmt Parsing Not implemented yet")
}
