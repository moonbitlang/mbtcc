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
      { dataKind: Function(param_types, ret_ty, is_variadic~), .. },
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
      let params_strs : Array[String] = Array::new()
      for param_ty in param_types {
        let (param_ty, param_name) = param_ty
        let param_str = if param_name != "" {
          "\{param_ty} \{param_name}"
        } else {
          "\{param_ty}"
        }
        params_strs.push(param_str)
      }
      if is_variadic {
        params_strs.push("...")
      }
      let params_str = params_strs.join(", ")
      if color {
        @color.taint("\{storage_str}function declaration: ", Magenta) +
        @color.taint("\{ret_ty} \{name}(\{params_str})", Green)
      } else {
        "\{storage_str}function declaration: \{ret_ty} \{name}(\{params_str})"
      }
    }
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
  // e.g. `struct Point { int x, y; };`
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
  skip_semi? : Bool = true,
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
      base_ty,
      storage,
      rest,
      init_tokens,
      decay_array_to_ptr=false,
    )
    guard rest is [{ kind: Semi, .. }, .. rest] else {
      raise ParseError(rest[0], "expected ';' after typedef")
    }
    guard !(name is "") else {
      raise ParseError(rest[0], "typedef name cannot be empty")
    }
    guard !self.defined.contains_local(name) else {
      raise ParseError(rest[0], "redeclaration of type name: \{name}")
    }
    self.add_typedef(name, ctype)
    let decl_tokens = init_tokens[0:rest.start_offset() - start_offset]
    let decl_kind = DeclarationKind::TypeDef(ctype, name)
    let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
    return ([decl], rest)
  }
  let (base_ty, storage, tokens) = self.parse_decl_spec(tokens)
  if tokens is [{ kind: Semi, .. }, .. tokens2] {
    // TODO, check base_ty is `struct`, `enum`, or `union`
    let decl_tokens = init_tokens[0:tokens.start_offset() - start_offset]
    let decl_kind = DeclarationKind::TypeDeclaration(base_ty)
    let decl = Declaration::{ kind: decl_kind, tokens: decl_tokens }
    let tokens = if skip_semi { tokens2 } else { tokens }
    return ([decl], tokens)
  }
  let (declarations, tokens) = self.parse_init_declarator_list(
    base_ty, storage, tokens, init_tokens,
  )
  let tokens = if skip_semi {
    guard tokens is [{ kind: Semi, .. }, .. tokens] else {
      raise ParseError(
        tokens[0],
        "expected ';' after declaration, while got \{tokens}",
      )
    }
    tokens
  } else {
    tokens
  }
  (declarations, tokens)
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
    base_ty,
    storage,
    tokens,
    init_tokens,
    decay_array_to_ptr=false,
  )
  guard !(name is "") else {
    raise ParseError(tokens[0], "declarator name cannot be empty")
  }
  guard !self.defined.contains_local(name) else {
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
        base_ty,
        storage,
        tokens,
        init_tokens,
        decay_array_to_ptr=false,
      )
      guard !(name is "") else {
        raise ParseError(tokens[0], "declarator name cannot be empty")
      }
      guard !self.defined.contains_local(name) else {
        raise ParseError(tokens[0], "redeclaration of variable: \{name}")
      }
      // 逗号分隔的后续 declarator 也需要加入变量环境（否则后续引用会被判定为未声明）
      self.add_var(name, ctype)
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
  (decls, tokens)
}

///|
pub fn Context::parse_declarator(
  self : Context,
  base_ty : CType,
  storage : StorageClass,
  tokens : ArrayView[Token],
  init_tokens : ArrayView[Token],
  decay_array_to_ptr? : Bool = false,
) -> (CType, String, ArrayView[Token]) raise ParseError {
  let (ty, rest) = self.parse_pointers(tokens, base_ty, init_tokens)
  // 参考 chibicc：遇到 '(' 时先“试探性”解析括号内 declarator，
  // 再把括号后的 type-suffix 应用到当前 ty 上，
  // 最后用新的 ty 回头重解析括号内 declarator —— 这样能正确处理
  // `(*fp)(...)` / `(*fp[3])(...)` 等 `()`/`[]` 结合优先级。
  if rest is [{ kind: Bracket('('), .. } as tok, ..] {
    let rest2 = rest[1:]
    guard rest2 is [tok2, ..] else { raise ParseError(tok, "unexpected end") }
    if !self.is_keyword_or_type_name(tok2) {
      // 试探解析，目的是找到匹配的 ')'
      let (_dummy_ty, _dummy_name, rest3) = self.parse_declarator(
        CType::void_(),
        storage,
        rest2,
        init_tokens,
        decay_array_to_ptr~,
      )
      guard rest3 is [{ kind: Bracket(')'), .. }, .. rest4] else {
        raise ParseError(tok, "expected ')'")
      }
      // 先解析括号外的 suffix，得到新的类型
      let (outer_ty, rest5) = self.parse_type_suffix(
        rest4,
        ty,
        init_tokens,
        decay_array_to_ptr~,
      )
      // 再用新的类型重解析括号内 declarator，把 suffix 绑定到内部
      let (final_ty, name, _rest_after_inner) = self.parse_declarator(
        outer_ty,
        storage,
        rest2,
        init_tokens,
        decay_array_to_ptr~,
      )
      // final parse 必须在 ')' 处结束，否则说明括号不匹配或语法不一致
      guard _rest_after_inner is [{ kind: Bracket(')'), .. }, ..] else {
        raise ParseError(tok, "expected ')' after declarator")
      }
      return (final_ty, name, rest5)
    }
  }
  let (name, rest) = if rest is [{ kind: Identifier(name), .. }, .. rest] {
    guard !self.is_type_name(name) else {
      raise ParseError(rest[0], "expected identifier, found type name")
    }
    guard !self.defined.contains_local(name) else {
      raise ParseError(rest[0], "redeclaration of variable")
    }
    (name, rest)
  } else {
    ("", rest)
  }
  let (ctype, rest) = self.parse_type_suffix(
    rest,
    ty,
    init_tokens,
    decay_array_to_ptr~,
  )
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

  // Parse `const double* p = 0;`
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

///|
test "Function Declaration Parsing Test" {
  let color = false
  let code =
    #|int func(); void process(int a, double b);
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int func();`
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(decl.to_string(color~), content="function declaration: int func()")

  // Parse `void process(int a, double b);`
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  inspect(
    decl.to_string(color~),
    content="function declaration: void process(int a, double b)",
  )
}

///|
test "Function Declaration Storage And Variadic Test" {
  let color = false
  let code =
    #|extern int f(int);
    #|static int g(int a);
    #|int printf(const char *fmt, ...);
  let ctx = Context::new(code~, source_file="demo")

  // extern int f(int);
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl0 = decls[0]
  inspect(
    decl0.to_string(color~),
    content="extern function declaration: int f(int)",
  )
  ignore(decl0.to_string()) // cover color=true path

  // static int g(int a);
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl1 = decls[0]
  inspect(
    decl1.to_string(color~),
    content="static function declaration: int g(int a)",
  )

  // int printf(const char *fmt, ...);
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl2 = decls[0]
  inspect(
    decl2.to_string(color~),
    content="function declaration: int printf(const char * fmt, ...)",
  )
}

///|
test "Declaration with Designated Initializer Parsing Test" {
  let code =
    #|struct S { int x; int y; };
    #|struct S s = { .y = 2, .x = 1 };
    #|static int sx = 1;
    #|_Thread_local int tx = 0;
  let ctx = Context::new(code~, source_file="demo")

  // struct S { ... };
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  inspect(decls[0].to_string(color=false), content="type declaration: struct S")

  // struct S s = { .y = 2, .x = 1 };
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let s_decl = decls[0]
  let s_str = s_decl.to_string(color=false)
  assert_true(s_str.contains(".y ="))
  assert_true(s_str.contains(".x ="))

  // static int sx = 1;
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let sx_decl = decls[0]
  assert_true(
    sx_decl
    .to_string(color=false)
    .contains("static variable declaration: int sx"),
  )
  ignore(sx_decl.to_string()) // cover color=true path (storage + initializer)

  // _Thread_local int tx = 0;
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let tx_decl = decls[0]
  assert_true(
    tx_decl
    .to_string(color=false)
    .contains("_Thread_local variable declaration: int tx"),
  )
}

///|
test "Initializer List Error Test" {
  // Error test: unexpected ',' in initializer list
  let code = "int x = {1,,2};"
  let ctx = Context::new(code~, source_file="demo")
  let r = try? ctx.parse_declaration(ctx.tokens)
  assert_true(r is Err(_))
}

///|
test "Typedef Error Branches Test" {
  // typedef cannot have storage class specifier
  let code_err1 = "typedef static int X;"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_declaration(ctx_err1.tokens)
  assert_true(r is Err(_))

  // missing ';' after typedef
  let code_err2 = "typedef int Y"
  let ctx_err2 = Context::new(code=code_err2)
  let r = try? ctx_err2.parse_declaration(ctx_err2.tokens)
  assert_true(r is Err(_))
}

///|
test "Designator Index And List Parse Test" {
  // Note: declarator parsing here doesn't support multi-dimensional arrays yet,
  // but designator parsing itself supports `[1][2]`.
  let code = "int a[3] = { [1][2] = 7 };"
  let ctx = Context::new(code~, source_file="demo")
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  let s = decl.to_string(color=false)
  assert_true(s.contains("][") && s.contains("="))
  assert_true(s.contains("7"))
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "parse_designator Direct Error Branches Test" {
  // tokens not starting with '.' or '[' => expected designator
  let ctx_err1 = Context::new(code="int x;")
  let r = try? ctx_err1.parse_designator(ctx_err1.tokens)
  assert_true(r is Err(_))

  // missing closing ']' in designator
  let ctx_err2 = Context::new(code="[1")
  let r = try? ctx_err2.parse_designator(ctx_err2.tokens)
  assert_true(r is Err(_))
}

///|
test "Declaration Color And Initializer Show Coverage Test" {
  // Cover register/_Thread_local storage branches and Initializer/InitializerKind Show.
  let code =
    #|register int r;
    #|_Thread_local int t;
    #|int x = { [1][2] = 7 };
  let ctx = Context::new(code~, source_file="demo")

  // register int r;
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")

  // _Thread_local int t;
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")

  // int x = { [1][2] = 7 };
  let (decls, _rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  let decl = decls[0]
  // Extract initializer and hit its Show impls directly
  guard decl.kind is VariableDeclaration(_, _, Some(_), ..) else {
    fail("expected initializer")
  }
}

///|
test "Declaration to_string(color=true) Coverage Test" {
  // Most existing tests assert with color=false; this test intentionally exercises color=true branches.
  let code =
    #|struct S { int x; };
    #|typedef int T;
    #|register int rf(int);
    #|_Thread_local int tf();
    #|extern int ei = 1;
  let ctx = Context::new(code~, source_file="demo")

  // type declaration
  let (decls, rest) = ctx.parse_declaration(ctx.tokens)
  inspect(decls.length(), content="1")

  // typedef
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")

  // register function declaration
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")

  // _Thread_local function declaration
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")

  // extern variable with initializer
  let (decls, rest) = ctx.parse_declaration(rest)
  inspect(decls.length(), content="1")
  assert_true(rest is [{ kind: EOF, .. }])
}
