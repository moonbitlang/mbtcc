

pub struct Program {
  externals: Array[ExternalDeclaration]
} derive(Eq)

pub fn Program::to_string(
  self: Program,
  color?: Bool = true
) -> String {
  self.externals.map(e => e.to_string(color~)).join("\n\n");
}

pub impl Show for Program with output(self, logger) {
  logger.write_string(self.to_string(color=true));
}

pub fn Context::parse(self: Context) -> Program raise ParseError {
  let tokens = self.tokens[:];
  let externals = Array::new()
  loop tokens {
    [{ kind: EOF, ..}] => break
    [] => {
      println("Compiler ICE: unexpected end of tokens in parse_program");
      panic()
    }
    tokens => {
      let (external, rest) = self.parse_external_declaration(tokens);
      externals.append(external);
      continue rest;
    }
  }
  Program::{ externals }
}
