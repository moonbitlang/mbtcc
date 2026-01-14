///|
pub suberror ParseError {
  ParseError(Token, String)
}

///|
pub impl Show for ParseError with output(self, logger) {
  let ParseError(tok, msg) = self
  logger.write_string("\{tok}: \{msg}")
}

///|
pub struct Program {
  externals : Array[ExternalDeclaration]
} derive(Eq)

///|
pub fn Program::new() -> Program {
  Program::{ externals: Array::new() }
}

///|
pub fn Program::is_empty(self : Self) -> Bool {
  self.externals.is_empty()
}

///|
pub fn Program::to_string(self : Program, color? : Bool = true) -> String {
  self.externals.map(e => e.to_string(color~)).join("\n")
}

///|
pub impl Show for Program with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn Context::parse(self : Context) -> Program raise ParseError {
  let tokens = self.tokens[:]
  let externals = self.prog.externals
  loop tokens {
    [{ kind: EOF, .. }] => break
    [] => {
      println("Compiler ICE: unexpected end of tokens in parse_program")
      panic()
    }
    // Ignore stray semicolons
    [{ kind: Semi, .. }, .. tokens] => continue tokens
    tokens => {
      let (external, rest) = self.parse_external_declaration(tokens)
      externals.append(external)
      continue rest
    }
  }
  self.prog
}
