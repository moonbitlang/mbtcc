///|
pub suberror ParseError {
  ParseError(Token, String)
}

///|
typealias @lexer.Token

///|
typealias @env.Env

///|
typealias @either.Either

#callsite(autofill(loc))
fn skip_semi(tokens: ArrayView[Token], loc~: SourceLoc) -> ArrayView[Token] raise {
  guard tokens is [{kind: Semi, ..}, ..rest] else {
    fail("", loc~)
  }
  rest
}
