///|
pub struct Context {
  code : String
  source_file : String
  tokens : Array[Token]
  // Symbol table
  mut defined : Env[String, SymbolKind]
  // enum, struct, union  type tags
  mut tags : Env[String, CTypeDataKind]
  errs : Array[ParseError]
  prog : Program
}

///|
enum SymbolKind {
  Variable(CType)
  TypeDef(CType)
  Label
  EnumMember(CTypeDataKind, Int)
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
    tags: Env::new(),
    errs: Array::new(),
    prog: Program::new(),
  }
}

///|
pub fn Context::new(
  code~ : String,
  source_file? : String = "demo",
  preprocess? : Bool = true,
) -> Context raise {
  let lexer_ctx = @lexer.Context::new(code~, source_file~)
  let _ = lexer_ctx.tokenize()
  let lexer_ctx = if preprocess {
    @preprocess.preprocess(lexer_ctx)
  } else {
    lexer_ctx
  }
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
  enum_type : CTypeDataKind,
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
pub fn Context::get_tag_ctype(self : Context, name : String) -> CTypeDataKind? {
  self.tags.get(name)
}

///|
pub fn Context::add_tag(
  self : Context,
  name : String,
  dataKind : CTypeDataKind,
) -> Unit {
  self.tags.set(name, dataKind)
}

///|
pub fn Context::is_name_a_tag(self : Context, name : String) -> Bool {
  match self.tags.get(name) {
    Some(_) => true
    _ => false
  }
}

///|
pub fn Context::push_scope(self : Context) -> Unit {
  let new_defined = Env::new(parent=Some(self.defined))
  self.defined = new_defined
  let new_tags = Env::new(parent=Some(self.tags))
  self.tags = new_tags
}

///|
#callsite(autofill(loc))
pub fn Context::pop_scope(self : Context, loc~ : SourceLoc) -> Unit {
  match self.defined.parent {
    Some(parent) => self.defined = parent
    None => {
      println("Compiler ICE: Tried to pop scope on top-level scope")
      println("Error: \{loc}")
      panic()
    }
  }
  match self.tags.parent {
    Some(parent) => self.tags = parent
    None => {
      println("Compiler ICE: Tried to pop scope on top-level scope")
      println("Error: \{loc}")
      panic()
    }
  }
}

///|
pub fn Context::catch_err(self : Context, err : ParseError) -> Unit {
  self.errs.push(err)
}

///|
test "Context Scope And Symbol Table Test" {
  let ctx = Context::new(code="", source_file="demo")
  ctx.add_var("a", CType::int())
  assert_true(ctx.is_var_name("a"))
  assert_true(ctx.get_var_ctype("a") is Some(_))
  ctx.add_typedef("MyInt", CType::int())
  assert_true(ctx.is_type_name("MyInt"))
  assert_true(ctx.get_typename_ctype("MyInt") is Some(_))
  ctx.add_label("L")
  assert_true(ctx.is_label("L"))
  ctx.add_tag("Point", Struct("Point", []))
  assert_true(ctx.is_name_a_tag("Point"))
  assert_true(ctx.get_tag_ctype("Point") is Some(_))
  ctx.add_enum_member("E0", Enum("E", []), 0)
  assert_true(ctx.is_enum_member("E0"))

  // scope push/pop should restore previous env
  ctx.push_scope()
  ctx.add_var("b", CType::int())
  assert_true(ctx.is_var_name("b"))
  ctx.pop_scope()
  assert_true(!ctx.is_var_name("b"))
  assert_true(ctx.is_var_name("a"))
}

///|
test "Context Catch Error Test" {
  let code = "return 1"
  let ctx = Context::new(code~, source_file="demo")
  try ctx.parse_statement(ctx.tokens[:]) catch {
    e => {
      ctx.catch_err(e)
      inspect(ctx.errs.length(), content="1")
    }
  } noraise {
    _ => fail("expected parse error")
  }
}
