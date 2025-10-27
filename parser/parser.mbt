///|
pub suberror ParseError {
  ParseError(Token, String)
}

///|
typealias @lexer.Token

///|
pub struct Context {
  code: String
  source_file : String
  tokens: Array[Token]
}

///|
pub fn Context::from_lexer(lexer_ctx: @lexer.Context) -> Context {
  let { code, source_file, tokens, err_toks } = lexer_ctx
  // TODO: Add error handling
  ignore(err_toks)
  Context::{ code, source_file, tokens }
}

///|
pub fn Context::new(code~: String, source_file~: String) -> Context {
  let lexer_ctx = @lexer.Context::new(code~, source_file~)
  let _ = lexer_ctx.tokenize()
  Context::from_lexer(lexer_ctx)
}
