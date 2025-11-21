///|
pub struct Context {
  code : String
  source_file : String
  tokens : Array[Token]
  // Left Type means Variable defined, Right means type defined.
  defined : Env[String, SymbolKind]
  errs : Array[ParseError]
}

///|
enum SymbolKind {
  Variable(CType)
  TypeDef(CType)
  Label
  EnumMember(CType, Int)
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
  self.defined.set(name, TypeDef(ctype))
}

///|
pub fn Context::add_var(self : Context, name : String, ctype : CType) -> Unit {
  self.defined.set(name, Variable(ctype))
}

///|
pub fn Context::add_label(self : Context, name : String) -> Unit {
  self.defined.set(name, Label)
}

///|
pub fn Context::add_enum_member(
  self : Context,
  vari : String,
  enum_type : CType,
  value : Int,
) -> Unit {
  self.defined.set(vari, EnumMember(enum_type, value))
}

///|
pub fn Context::is_type_name(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(TypeDef(_)) => true
    _ => false
  }
}

///|
pub fn Context::is_type_tok(self : Context, tok : Token) -> Bool {
  if tok.kind is Keyword(kw) {
    match kw {
      Void
      | Char
      | Short
      | Int
      | Long
      | Float
      | Double
      | Signed
      | Unsigned
      | Bool
      | Struct
      | Union
      | Enum => true
      _ => false
    }
  } else if tok.kind is Identifier(name) {
    self.is_type_name(name)
  } else {
    false
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
pub fn Context::is_label(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(Label) => true
    _ => false
  }
}

///|
pub fn Context::is_var_name(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(Variable(_)) => true
    _ => false
  }
}

///|
pub fn Context::is_enum_member(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(EnumMember(_, _)) => true
    _ => false
  }
}

///|
pub fn Context::is_name_has_been_defined(self : Context, name : String) -> Bool {
  match self.defined.get(name) {
    Some(_) => true
    _ => false
  }
}

///|
pub fn Context::get_var_ctype(self : Context, name : String) -> CType? {
  match self.defined.get(name) {
    Some(Variable(ctype)) => Some(ctype)
    _ => None
  }
}

///|
pub fn Context::get_typename_ctype(self : Context, name : String) -> CType? {
  match self.defined.get(name) {
    Some(TypeDef(ctype)) => Some(ctype)
    _ => None
  }
}

///|
pub fn Context::catch_err(self : Context, err : ParseError) -> Unit {
  self.errs.push(err)
}
