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

///|
pub fn next_check_point(tokens : ArrayView[Token]) -> ArrayView[Token] {
  loop tokens {
    [{ kind: Semi, .. }, .. rest] => break rest
    [_, .. rest] => continue rest
    [] as tokens => break tokens
  }
}
