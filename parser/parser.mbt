///|
pub suberror ParseError {
  ParseError(Token, String)
}

///|
pub impl Show for ParseError with output(self, logger) {
  let ParseError(tok, msg) = self
  logger.write_string("\{tok}: \{msg}")
}
