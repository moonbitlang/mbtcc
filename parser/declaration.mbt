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
    VariableDeclaration(
      ctype,
      is_extern~,
      is_static~,
      is_register~,
      is_thread_local~,
      name,
      None
    ) => {
      let storage_strs = Array::new()
      if is_extern {
        storage_strs.push("extern")
      }
      if is_static {
        storage_strs.push("static")
      }
      if is_register {
        storage_strs.push("register")
      }
      if is_thread_local {
        storage_strs.push("_Thread_local")
      }
      let storage_str = if storage_strs.length() > 0 {
        storage_strs.join(" ") + " "
      } else {
        ""
      }
      if color {
        @color.taint("\{storage_str}variable declaration: ", Magenta) +
        @color.taint("\{ctype}", Green) +
        " \{name}"
      } else {
        "\{storage_str}variable declaration: \{ctype} \{name}"
      }
    }
    VariableDeclaration(
      ctype,
      is_extern~,
      is_static~,
      is_register~,
      is_thread_local~,
      name,
      Some(initializer)
    ) => {
      let storage_strs = Array::new()
      if is_extern {
        storage_strs.push("extern")
      }
      if is_static {
        storage_strs.push("static")
      }
      if is_register {
        storage_strs.push("register")
      }
      if is_thread_local {
        storage_strs.push("_Thread_local")
      }
      let storage_str = if storage_strs.length() > 0 {
        storage_strs.join(" ") + " "
      } else {
        ""
      }
      let initializer = initializer.to_string(color~)
      let initializer_lines = initializer.split("\n")
      let initializer_formatted = format_lines(
        initializer_lines,
        head_with="└-",
        continue_with="  ",
      )
      if color {
        @color.taint("\{storage_str}variable declaration: ", Magenta) +
        @color.taint("\{ctype}", Green) +
        " \{name}\n\{initializer_formatted}"
      } else {
        "\{storage_str}variable declaration: \{ctype} \{name}\n\{initializer_formatted}"
      }
    }
  }
  s
}

///|
pub impl Show for Declaration with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub enum DeclarationKind {
  // e.h. `struct Point { int x, y; };`
  TypeDeclaration(CType)
  // e.g. `typedef int MyInt;`
  TypeDef(CType, String)
  VariableDeclaration(
    CType,
    is_static~ : Bool,
    is_extern~ : Bool,
    is_register~ : Bool,
    is_thread_local~ : Bool,
    String,
    Initializer?
  )
} derive(Eq)

///|
pub(all) struct Initializer {
  kind : InitializerKind
  tokens : ArrayView[Token]
}

///|
pub fn Initializer::to_string(self : Self, color? : Bool = true) -> String {
  self.kind.to_string(color~)
}

///|
pub impl Eq for Initializer with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for Initializer with output(self, logger) {
  logger.write_string(self.kind.to_string(color=true))
}

///|
pub(all) enum InitializerKind {
  AssignExpr(AssignExpr)
  // Only appeared in initializer lists
  Designation(Designator, Initializer)
  InitializerList(Array[Initializer])
} derive(Eq)

///|
pub fn InitializerKind::to_string(self : Self, color? : Bool = true) -> String {
  let s = match self {
    AssignExpr(expr) => expr.to_string(color~)
    Designation(designator, initializer) =>
      "\{designator} = \{initializer.to_string(color~)}"
    InitializerList(initializers) => {
      let init_strs : Array[String] = Array::new()
      for initializer in initializers {
        init_strs.push(initializer.to_string(color~))
      }
      "{ " + init_strs.join(", ") + " }"
    }
  }
  s
}

///|
pub impl Show for InitializerKind with output(self, logger) {
  logger.write_string(self.to_string(color=true))
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
///
/// TODO: MayBe we can do semantic check during designator parsing.
pub fn Context::parse_designator(
  self : Context,
  tokens : ArrayView[Token],
) -> (Designator, ArrayView[Token]) raise ParseError {
  let designators : Array[Designator] = Array::new()
  let rest = loop tokens {
    [{ kind: Dot, .. }, { kind: Identifier(name), .. }, .. rest] => {
      let designator = Designator::Field(name)
      designators.push(designator)
      continue rest
    }
    [{ kind: Bracket('['), .. }, .. tokens] => {
      let (expr, rest) = self.parse_constant_expr(tokens)
      guard rest is [{ kind: Bracket(']'), .. }, .. rest] else {
        raise ParseError(rest[0], "expected ']' in designator")
      }
      let designator = Designator::Index(expr)
      designators.push(designator)
      continue rest
    }
    tokens => break tokens
  }
  match designators.length() {
    0 => raise ParseError(tokens[0], "expected designator")
    1 => (designators[0], rest)
    _ => (Designator::DesignatorList(designators), rest)
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
    let (base_ty, storage, rest) = self.parse_decl_spec(tokens)
    guard storage
      is {
        is_static: false,
        is_extern: false,
        is_register: false,
        is_thread_local: false,
      } else {
      raise ParseError(tokens[0], "typedef cannot have storage class specifier")
    }
    let (ctype, name, rest) = self.parse_declarator(
      base_ty, storage, rest, init_tokens,
    )
    guard rest is [{ kind: Semi, .. }, .. rest] else {
      raise ParseError(rest[0], "expected ';' after typedef")
    }
    guard !(name is "") else {
      raise ParseError(rest[0], "typedef name cannot be empty")
    }
    guard !self.is_name_has_been_defined(name) else {
      raise ParseError(rest[0], "redeclaration of type name: \{name}")
    }
    self.add_typedef(name, ctype)
    let decl_tokens = init_tokens[0:rest.start_offset() - start_offset]
    let decl_kind = DeclarationKind::TypeDef(ctype, name)
    let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
    return ([decl], rest)
  }
  let (base_ty, storage, tokens) = self.parse_decl_spec(tokens)
  if tokens is [{ kind: Semi, .. }, .. tokens] {
    // TODO, check base_ty is `struct`, `enum`, or `union`
    let decl_tokens = init_tokens[0:tokens.start_offset() - start_offset]
    let decl_kind = DeclarationKind::TypeDeclaration(base_ty)
    let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
    return ([decl], tokens)
  }
  self.parse_init_declarator_list(base_ty, storage, tokens, init_tokens)
}

///|
pub fn Context::parse_init_declarator_list(
  self : Context,
  base_ty : CType,
  storage : StorageClass,
  tokens : ArrayView[Token],
  init_tokens : ArrayView[Token],
) -> (Array[Declaration], ArrayView[Token]) raise ParseError {
  let decls : Array[Declaration] = Array::new()
  let (ctype, name, tokens) = self.parse_declarator(
    base_ty, storage, tokens, init_tokens,
  )
  guard !(name is "") else {
    raise ParseError(tokens[0], "declarator name cannot be empty")
  }
  guard !self.is_name_has_been_defined(name) else {
    raise ParseError(tokens[0], "redeclaration of variable: \{name}")
  }
  self.add_var(name, ctype)
  let (initializer, tokens) = if tokens
    is [{ kind: AssignOp("="), .. }, .. tokens] {
    let (initializer, tokens) = self.parse_initializer(tokens)
    (Some(initializer), tokens)
  } else {
    (None, tokens)
  }
  let decl_tokens = init_tokens[0:tokens.start_offset() -
    init_tokens.start_offset()]
  let { is_static, is_extern, is_register, is_thread_local } = storage
  let decl_kind = VariableDeclaration(
    ctype,
    is_static~,
    is_extern~,
    is_register~,
    is_thread_local~,
    name,
    initializer,
  )
  let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
  decls.push(decl)
  let tokens = loop tokens {
    [{ kind: Comma, .. }, { kind: Comma, .. } as tok, ..] =>
      raise ParseError(tok, "unexpected ',' in declaration")
    [{ kind: Comma, .. }, .. tokens] => {
      let (ctype, name, tokens) = self.parse_declarator(
        base_ty, storage, tokens, init_tokens,
      )
      guard !(name is "") else {
        raise ParseError(tokens[0], "declarator name cannot be empty")
      }
      guard !self.is_name_has_been_defined(name) else {
        raise ParseError(tokens[0], "redeclaration of variable: \{name}")
      }
      let (decl_kind, tokens) = if tokens
        is [{ kind: AssignOp("="), .. }, .. tokens] {
        let (initializer, tokens) = self.parse_initializer(tokens)
        let kind = VariableDeclaration(
          ctype,
          is_static~,
          is_extern~,
          is_register~,
          is_thread_local~,
          name,
          Some(initializer),
        )
        (kind, tokens)
      } else {
        let kind = VariableDeclaration(
          ctype,
          is_static~,
          is_extern~,
          is_register~,
          is_thread_local~,
          name,
          None,
        )
        (kind, tokens)
      }
      let decl_tokens = init_tokens[0:tokens.start_offset() -
        init_tokens.start_offset()]
      let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
      decls.push(decl)
      continue tokens
    }
    tokens => break tokens
  }
  guard tokens is [{ kind: Semi, .. }, .. tokens] else {
    raise ParseError(
      tokens[0],
      "expected ';' after declaration, while got \{tokens}",
    )
  }
  (decls, tokens)
}

///|
pub fn Context::parse_declarator(
  self : Context,
  base_ty : CType,
  storage : StorageClass,
  tokens : ArrayView[Token],
  init_tokens : ArrayView[Token],
) -> (CType, String, ArrayView[Token]) raise ParseError {
  let (ty, rest) = self.parse_pointers(tokens, base_ty, init_tokens)
  if rest is [{ kind: Bracket('('), .. }, .. rest2] {
    let ty = CType::void_()
    let (_, _, rest) = self.parse_declarator(ty, storage, rest2, init_tokens)
    guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
      raise ParseError(rest[0], "expected ')'")
    }
    let (ctype, _) = self.parse_type_suffix(rest, ty, init_tokens)
    return self.parse_declarator(ctype, storage, rest2, init_tokens)
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
  (ctype, name, rest)
}

///|
pub fn Context::parse_initializer(
  self : Context,
  tokens : ArrayView[Token],
) -> (Initializer, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = tokens.start_offset()
  let (init_kind, rest) = match tokens {
    [{ kind: Dot | Bracket('['), .. }, ..] => {
      let (designator, rest) = self.parse_designator(tokens)
      guard rest is [{ kind: AssignOp("="), .. }, .. rest] else {
        raise ParseError(rest[0], "expected '=' after designator")
      }
      let (initializer, rest) = self.parse_initializer(rest)
      let init_kind = InitializerKind::Designation(designator, initializer)
      (init_kind, rest)
    }
    [{ kind: Bracket('{'), .. }, .. rest] => {
      let initializers : Array[Initializer] = Array::new()
      let rest = loop rest {
        [{ kind: Bracket('}'), .. }, .. rest] => break rest
        [{ kind: Comma, .. }, { kind: Comma, .. } as tok, ..] =>
          raise ParseError(tok, "unexpected ',' in initializer list")
        [{ kind: Comma, .. }, .. rest] => continue rest
        tokens => {
          let (initializer, rest) = self.parse_initializer(tokens)
          initializers.push(initializer)
          continue rest
        }
      }
      let init_kind = InitializerKind::InitializerList(initializers)
      (init_kind, rest)
    }
    tokens => {
      let (expr, rest) = self.parse_assign_expr(tokens)
      let init_kind = InitializerKind::AssignExpr(expr)
      (init_kind, rest)
    }
  }
  let init_tokens = init_tokens[0:rest.start_offset() - start_offset]
  let initializer = Initializer::{ kind: init_kind, tokens: init_tokens }
  (initializer, rest)
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
  inspect(decl.to_string(color~), content="variable declaration: int x")

  // Parse `int* y;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(decl.to_string(color~), content="variable declaration: int * y")

  // Parse `const int z;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(decl.to_string(color~), content="variable declaration: const int z")

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
  inspect(decl0.to_string(color~), content="variable declaration: float a")

  // Second declarator: `float *b`
  let decl1 = decls[1]
  inspect(decl1.to_string(color~), content="variable declaration: float * b")

  // Third declarator: `float c`
  let decl2 = decls[2]
  inspect(decl2.to_string(color~), content="variable declaration: float c")
}

///|
test "Declaration with Storage Class Specifiers Parsing Test" {
  let color = false
  let code =
    #|int static x; extern const double* p; float register y; _Thread_local char c;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `static int x;`
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(decl.to_string(color~), content="static variable declaration: int x")

  // Parse `extern const double* p;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="extern variable declaration: const double * p",
  )

  // Parse `register float y;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="register variable declaration: float y",
  )

  // Parse `_Thread_local char c;`
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="_Thread_local variable declaration: char c",
  )
}

///|
test "Typedef Declaration Parsing Test" {
  let color = false
  let code =
    #|typedef int MyInt; typedef const double* MyDoublePtr;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `typedef int MyInt;`
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(decl.to_string(color~), content="typedef: int MyInt")

  // Parse `typedef const double* MyDoublePtr;`
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(decl.to_string(color~), content="typedef: const double * MyDoublePtr")
}

///|
test "Declaration with Initializer Parsing Test" {
  let color = false
  let code =
    #|int x = 10; const double* p = 0; float a = 3.14, *b = &a;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int x = 10;`
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content=(
      #|variable declaration: int x
      #|└-int literal 10 (int)
    ),
  )

  // Parse `const double* p = NULL;`
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content=(
      #|variable declaration: const double * p
      #|└-int literal 0 (int)
    ),
  )

  // Parse `float a = 3.14, *b = &a;` - multiple declarators with initializers
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="2")

  // First declarator: `float a = 3.14`
  let decl0 = decls[0]
  inspect(
    decl0.to_string(color~),
    content=(
      #|variable declaration: float a
      #|└-double literal 3.14 (double)
    ),
  )

  // Second declarator: `float *b = &a`
  let decl1 = decls[1]
  inspect(
    decl1.to_string(color~),
    content=(
      #|variable declaration: float * b
      #|└-unary operator & (float *)
      #|  └-variable a (float)
    ),
  )
}
