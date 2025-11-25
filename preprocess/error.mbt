///|
pub suberror PreprecessError {
  InvalidIncludePath(String)
  Unimplemented(String)
  InvalidMacroDefinition(String)
  InvalidMacorInvocation(String)
  InvalidConstExprToken(Token, String)
  StrayElse(Token, String)
}
