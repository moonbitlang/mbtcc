///|
pub suberror ParseError {
  ParseError(Token, String)
}

///|
using @lexer {type Token}

///|
using @env {type Env}

///|
using @either {type Either}

///|
#callsite(autofill(loc))
fn skip_semi(
  tokens : ArrayView[Token],
  loc~ : SourceLoc,
) -> ArrayView[Token] raise {
  guard tokens is [{ kind: Semi, .. }, .. rest] else { fail("", loc~) }
  rest
}
