///|
pub struct Context {
  code : String
  source_file : String
  tokens : Array[Token]
  // Left Type means Variable defined, Right means type defined.
  defined : Env[String, Either[CType, CType]]
  errs : Array[ParseError]
}

///|
pub fn Context::from_lexer(lexer_ctx : @lexer.Context) -> Context {
  let { code, source_file, tokens, err_toks } = lexer_ctx
  // TODO: Add error handling
  ignore(err_toks)
  Context::{
    code,
    source_file,
    tokens,
    defined: Env::new(),
    errs: Array::new(),
  }
}

///|
pub fn Context::new(code~ : String, source_file? : String = "demo") -> Context {
  let lexer_ctx = @lexer.Context::new(code~, source_file~)
  let _ = lexer_ctx.tokenize()
  Context::from_lexer(lexer_ctx)
}

///|
pub fn Context::add_typedef(
  self : Context,
  name : String,
  ctype : CType,
) -> Unit {
  self.defined.set(name, Either::Right(ctype))
}

///|
pub fn Context::add_var(self : Context, name : String, ctype : CType) -> Unit {
  self.defined.set(name, Either::Left(ctype))
}

///|
pub fn Context::is_type_name(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(Right(_)) => true
    _ => false
  }
}

///|
pub fn Context::is_keyword_or_type_name(self : Self, tok : Token) -> Bool {
  match tok.kind {
    Keyword(_) => true
    Identifier(name) => self.is_type_name(name)
    _ => false
  }
}

///|
pub fn Context::is_var_name(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(Left(_)) => true
    _ => false
  }
}

///|
pub fn Context::get_var_ctype(self : Context, name : String) -> CType? {
  match self.defined.get(name) {
    Some(Left(ctype)) => Some(ctype)
    _ => None
  }
}

///|
pub fn Context::get_typename_ctype(self : Context, name : String) -> CType? {
  match self.defined.get(name) {
    Some(Right(ctype)) => Some(ctype)
    _ => None
  }
}

///|
pub fn Context::catch_err(self : Context, err : ParseError) -> Unit {
  self.errs.push(err)
}
