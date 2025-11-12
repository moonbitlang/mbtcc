///|
pub struct Declaration {
  kind : DeclarationKind
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Declaration with equal(self, other) {
  self.kind == other.kind
}

///|
pub fn Declaration::to_string(self : Self, color? : Bool = true) -> String {
  let s = match self.kind {
    TypeDeclaration(ctype) if color =>
      @color.taint("type declaration: ", Magenta) +
      @color.taint("\{ctype}", Green)
    TypeDeclaration(ctype) => "type declaration: \{ctype}"
    TypeDef(ctype, name) if color =>
      @color.taint("typedef: ", Magenta) +
      @color.taint("\{ctype}", Green) +
      " \{name}"
    TypeDef(ctype, name) => "typedef: \{ctype} \{name}"
    VariableDeclaration(ctype, name, None) if color =>
      @color.taint("variable declaration: ", Magenta) +
      @color.taint("\{ctype}", Green) +
      " \{name}"
    VariableDeclaration(ctype, name, None) =>
      "variable declaration: \{ctype} \{name}"
    VariableDeclaration(ctype, name, Some(initializer)) if color =>
      @color.taint("variable declaration: ", Magenta) +
      @color.taint("\{ctype}", Green) +
      " \{name} = \{initializer}"
    VariableDeclaration(ctype, name, Some(initializer)) =>
      "variable declaration: \{ctype} \{name} = \{initializer}"
  }
  s
}

///|
pub enum DeclarationKind {
  // e.h. `struct Point { int x, y; };`
  TypeDeclaration(CType)
  // e.g. `typedef int MyInt;`
  TypeDef(CType, String)
  VariableDeclaration(CType, String, Initializer?)
} derive(Eq)

///|
pub(all) struct Initializer {
  kind : InitializerKind
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Initializer with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for Initializer with output(self, logger) {
  logger.write_string("\{self.kind}")
}

///|
pub(all) enum InitializerKind {
  AssignExpr(AssignExpr)
  // Only appeared in initializer lists
  Designation(Designator, AssignExpr)
  InitializerList(Array[Initializer])
} derive(Eq)

///|
pub impl Show for InitializerKind with output(self, logger) {
  match self {
    AssignExpr(expr) => logger.write_string("\{expr}")
    Designation(designator, expr) =>
      logger.write_string("\{designator} = \{expr}")
    InitializerList(initializers) => {
      logger.write_string("{ ")
      for i, initializer in initializers {
        if i > 0 {
          logger.write_string(", ")
        }
        logger.write_string("\{initializer}")
      }
      logger.write_string(" }")
    }
  }
}

///|
pub(all) enum Designator {
  // e.g. `.field = value`
  Field(String)
  // Must Check if it is the constant expression
  // e.g. `[5] = 10`
  Index(ConstantExpr)
  // e.g. `[1][2] = value`
  DesignatorList(Array[Designator])
} derive(Eq)

///|
pub impl Show for Designator with output(self, logger) {
  match self {
    Field(name) => logger.write_string(".\{name}")
    Index(expr) => logger.write_string("[\{expr}]")
    DesignatorList(designators) =>
      for designator in designators {
        logger.write_string("\{designator}")
      }
  }
}

///|
pub fn Context::parse_declaration(
  self : Context,
  tokens : ArrayView[Token],
) -> (Array[Declaration], ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = tokens.start_offset()
  if tokens is [{ kind: Keyword(Typedef), .. }, .. tokens] {
    let (base_ty, rest) = self.parse_decl_spec(tokens)
    let (ctype, name, rest) = self.parse_declarator(base_ty, rest, init_tokens)
    guard rest is [{ kind: Semi, .. }, .. rest] else {
      raise ParseError(rest[0], "expected ';' after typedef")
    }
    guard !(name is "") else {
      raise ParseError(rest[0], "typedef name cannot be empty")
    }
    guard !self.is_type_name(name) && !self.is_var_name(name) else {
      raise ParseError(rest[0], "redeclaration of type name")
    }
    self.add_typedef(name, ctype)
    let decl_tokens = init_tokens[0:rest.start_offset() - start_offset]
    let decl_kind = DeclarationKind::TypeDef(ctype, name)
    let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
    return ([decl], rest)
  }
  let (base_ty, tokens) = self.parse_decl_spec(tokens)
  if tokens is [{ kind: Semi, .. }, .. tokens] {
    // TODO, check base_ty is `struct`, `enum`, or `union`
    let decl_tokens = init_tokens[0:tokens.start_offset() - start_offset]
    let decl_kind = DeclarationKind::TypeDeclaration(base_ty)
    let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
    return ([decl], tokens)
  }
  self.parse_init_declarator_list(base_ty, tokens, init_tokens)
}

///|
pub fn Context::parse_init_declarator_list(
  self : Context,
  base_ty : CType,
  tokens : ArrayView[Token],
  init_tokens : ArrayView[Token],
) -> (Array[Declaration], ArrayView[Token]) raise ParseError {
  let decls : Array[Declaration] = Array::new()
  let (ctype, name, tokens) = self.parse_declarator(
    base_ty, tokens, init_tokens,
  )
  let (initializer, tokens) = if tokens
    is [{ kind: AssignOp("="), .. }, .. tokens] {
    let (initializer, tokens) = self.parse_initializer(tokens, init_tokens)
    (Some(initializer), tokens)
  } else {
    (None, tokens)
  }
  let decl_tokens = init_tokens[0:tokens.start_offset() -
    init_tokens.start_offset()]
  let decl_kind = DeclarationKind::VariableDeclaration(ctype, name, initializer)
  let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
  decls.push(decl)
  let tokens = loop tokens {
    [{ kind: Comma, .. }, .. tokens] => {
      let (ctype, name, tokens) = self.parse_declarator(
        base_ty, tokens, init_tokens,
      )
      if tokens is [{ kind: AssignOp("="), .. }, .. tokens] {
        raise ParseError(tokens[0], "initializers are not supported yet")
      } else {
        let decl_tokens = init_tokens[0:tokens.start_offset() -
          init_tokens.start_offset()]
        let decl_kind = DeclarationKind::VariableDeclaration(ctype, name, None)
        let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
        decls.push(decl)
      }
      continue tokens
    }
    tokens => break tokens
  }
  guard tokens is [{ kind: Semi, .. }, .. tokens] else {
    raise ParseError(tokens[0], "expected ';' after declaration")
  }
  (decls, tokens)
}

///|
pub fn Context::parse_declarator(
  self : Context,
  base_ty : CType,
  tokens : ArrayView[Token],
  init_tokens : ArrayView[Token],
) -> (CType, String, ArrayView[Token]) raise ParseError {
  let (ty, rest) = self.parse_pointers(tokens, base_ty, init_tokens)
  if rest is [{ kind: Bracket('('), .. }, .. rest2] {
    let ty = CType::void_()
    let (_, _, rest) = self.parse_declarator(ty, rest2, init_tokens)
    guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
      raise ParseError(rest[0], "expected ')'")
    }
    let (ctype, _) = self.parse_type_suffix(rest, ty, init_tokens)
    return self.parse_declarator(ctype, rest2, init_tokens)
  }
  let (name, rest) = if rest is [{ kind: Identifier(name), .. }, .. rest] {
    guard !self.is_type_name(name) else {
      raise ParseError(rest[0], "expected identifier, found type name")
    }
    guard !(self.get_var_ctype(name) is Some(_)) else {
      raise ParseError(rest[0], "redeclaration of variable")
    }
    (name, rest)
  } else {
    ("", rest)
  }
  let (ctype, rest) = self.parse_type_suffix(rest, ty, init_tokens)
  if !(name is "") {
    self.add_var(name, ctype)
  }
  (ctype, name, rest)
}

///|
pub fn Context::parse_initializer(
  self : Context,
  tokens : ArrayView[Token],
  init_tokens : ArrayView[Token],
) -> (Initializer, ArrayView[Token]) raise ParseError {
  ignore(self)
  ignore(tokens)
  ignore(init_tokens)
  raise ParseError(tokens[0], "initializer parsing not implemented yet")
}

///|
test "Normal Declaration Parsing Test" {
  let color = false
  let code = 
    #|int x; int* y; const int z; const double**p; float a, *b, c;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int x;`
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="variable declaration: int x",
  )

  // Parse `int* y;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="variable declaration: int * y",
  )

  // Parse `const int z;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="variable declaration: const int z",
  )

  // Parse `const double**p;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="variable declaration: const double * * p",
  )

  // Parse `float a, *b, c;` - multiple declarators
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="3")
  
  // First declarator: `float a`
  let decl0 = decls[0]
  inspect(
    decl0.to_string(color~),
    content="variable declaration: float a",
  )
  
  // Second declarator: `float *b`
  let decl1 = decls[1]
  inspect(
    decl1.to_string(color~),
    content="variable declaration: float * b",
  )
  
  // Third declarator: `float c`
  let decl2 = decls[2]
  inspect(
    decl2.to_string(color~),
    content="variable declaration: float c",
  )
}
