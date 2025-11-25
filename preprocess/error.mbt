///|
pub suberror PreprecessError {
  InvalidIncludePath(String)
  InvalidMacroDefinition(String)
  InvalidMacorInvocation(String)
  InvalidConstExprToken(Token, String)
  StrayElse(Token, String)
}
