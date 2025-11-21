///|
///
/// External Declaration
///
/// External declarations are top-level declarations in a translation unit,
/// which can be either function definitions or declarations.
///
/// ## Examples
///
/// ```c
/// // Function definition
/// int add(int a, int b) {
///     return a + b;
/// }
///
/// // Function declaration
/// int multiply(int x, int y);
///
/// // Variable declaration
/// int global_var;
///
/// // Static function definition
/// static void helper() {
///     // implementation
/// }
/// ```
///
/// ## Grammar (EBNF)
///
/// external_declaration
///   : function_definition
///   | declaration
///   ;
///
/// function_definition
///   : declaration_specifiers declarator compound_statement
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_external_declaration(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (Array[ExternalDeclaration], ArrayView[Token]) raise ParseError
/// ```
pub struct ExternalDeclaration {
  kind : ExternalDeclarationKind
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ExternalDeclaration with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for ExternalDeclaration with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn ExternalDeclaration::to_string(
  self : Self,
  color? : Bool = true,
) -> String {
  match self.kind {
    FunctionDefinition(func_def) => func_def.to_string(color~)
    Declaration(decl) => decl.to_string(color~)
  }
}

///|
pub enum ExternalDeclarationKind {
  FunctionDefinition(FunctionDefinition)
  Declaration(Declaration)
} derive(Eq)

///|
pub struct FunctionDefinition {
  name : String
  params : Array[(CType, String)]
  ret_ty : CType
  is_static : Bool
  is_variadic : Bool
  body : CompoundStmt
}

///|
pub impl Eq for FunctionDefinition with equal(self, other) {
  self.name == other.name &&
  self.params == other.params &&
  self.ret_ty == other.ret_ty &&
  self.is_static == other.is_static &&
  self.is_variadic == other.is_variadic &&
  self.body == other.body
}

///|
pub impl Show for FunctionDefinition with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn FunctionDefinition::to_string(
  self : Self,
  color? : Bool = true,
) -> String {
  let storage_str = if self.is_static { "static " } else { "" }
  let prefix = if color {
    @color.taint("\{storage_str}function definition: ", Magenta) +
    @color.taint("\{self.name}", Green)
  } else {
    "\{storage_str}function definition: \{self.name}"
  }

  // Format parameters
  let params_strs : Array[String] = Array::new()
  for param_ty in self.params {
    let (param_ty, param_name) = param_ty
    let param_str = if param_name != "" {
      "\{param_ty} \{param_name}"
    } else {
      "\{param_ty}"
    }
    params_strs.push(param_str)
  }
  if self.is_variadic {
    params_strs.push("...")
  }
  let params_str = params_strs.join(", ")
  let signature = if color {
    @color.taint("(\{params_str}) -> \{self.ret_ty}", Blue)
  } else {
    "(\{params_str}) -> \{self.ret_ty}"
  }

  // Format body
  let body_str = self.body.to_string(color~)
  let body_lines = body_str.split("\n")
  let body_formatted = format_lines(
    body_lines,
    head_with="└-",
    continue_with="  ",
  )
  "\{prefix} \{signature}\n\{body_formatted}"
}

///|
/// Parse an external declaration from the given tokens.
///
/// Returns a tuple containing an array of parsed ExternalDeclarations
/// and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// int add(int a, int b) {
///     return a + b;
/// }
///
/// int multiply(int x, int y);
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "int add(int a, int b) { return a + b; }"
/// let ctx = Context::new(code~, source_file="demo")
/// let (ext_decls, rest) = ctx.parse_external_declaration(ctx.tokens)
/// inspect(ext_decls.length(), content="1")
/// inspect(
///   ext_decls[0].to_string(color=false),
///   content=(
///     #|function definition: add (int a, int b) -> int
///     #|└-body: compound statement
///     #|        └-[0]: return statement
///     #|               └-additive expr: + (int)
///     #|                 ├-variable a (int)
///     #|                 └-variable b (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse declaration fails.
///
///    e.g.,
///    ```c
///    ? add() {}  // invalid declaration specifier
///    ```
///
/// 2. Function definition is missing compound statement.
///
///    e.g.,
///    ```c
///    int add(int a, int b)  // missing function body
///    ```
///
/// 3. Function definition has multiple declarators.
///
///    e.g.,
///    ```c
///    int add(int a, int b), sub(int a, int b) {}  // invalid
///    ```
///
/// 4. Declaration is not a function type when followed by '{'.
///
///    e.g.,
///    ```c
///    int x {}  // variable cannot have body
///    ```
pub fn Context::parse_external_declaration(
  self : Context,
  tokens : ArrayView[Token],
) -> (Array[ExternalDeclaration], ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()

  // Parse declaration without consuming the semicolon
  let (decls, rest) = self.parse_declaration(tokens, skip_semi=false)

  // Check if followed by '{' (function definition) or ';' (declaration)
  if rest is [{ kind: Bracket('{'), .. }, ..] {
    // This is a function definition
    guard decls is [decl] else {
      raise ParseError(
        init_tokens[0],
        "Function definition must have exactly one declarator",
      )
    }
    guard decl.kind
      is VariableDeclaration(
        { dataKind: Function(param_types, ret_ty, is_variadic~), .. },
        is_static~,
        is_extern~,
        is_register~,
        is_thread_local~,
        name,
        initializer
      ) else {
      raise ParseError(
        init_tokens[0],
        "Only function declarations can have body",
      )
    }
    // Function definition cannot have extern, register, or thread_local
    guard !is_extern && !is_register && !is_thread_local else {
      raise ParseError(
        init_tokens[0],
        "Function definition cannot have extern, register, or _Thread_local storage class",
      )
    }

    // Function definition cannot have initializer
    guard initializer is None else {
      raise ParseError(
        init_tokens[0],
        "Function definition cannot have initializer",
      )
    }

    // Add function parameters to the context for parsing the function body
    for param in param_types {
      let (param_type, param_name) = param
      if param_name != "" {
        self.add_var(param_name, param_type)
      }
    }

    // Parse compound statement (function body)
    let (body, rest) = self.parse_compound_statement(rest)
    let func_def = FunctionDefinition::{
      name,
      params: param_types,
      ret_ty,
      is_static,
      is_variadic,
      body,
    }
    let ext_decl = ExternalDeclaration::{
      kind: FunctionDefinition(func_def),
      tokens: init_tokens[0:rest.start_offset() - start_offset],
    }
    return ([ext_decl], rest)
  } else if rest is [{ kind: Semi, .. }, .. rest] {
    // This is a normal declaration, consume the semicolon
    let ext_decls = decls.map(fn(decl) {
      let decl_tokens = decl.tokens
      ExternalDeclaration::{ kind: Declaration(decl), tokens: decl_tokens }
    })
    return (ext_decls, rest)
  } else {
    raise ParseError(rest[0], "Expected ';' or '{' after declaration")
  }
}

///|
test "External Declaration Parse Test" {
  let color = false
  let code =
    #|int add(int a, int b) { return a + b; } ;
    #|int multiply(int x, int y); ;
    #|int global_var; ;
    #|static void helper() { return; } ;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int add(int a, int b) { return a + b; }`
  let (ext_decls, rest) = ctx.parse_external_declaration(ctx.tokens)
  inspect(ext_decls.length(), content="1")
  inspect(
    ext_decls[0].to_string(color~),
    content=(
      #|function definition: add (int a, int b) -> int
      #|└-body: compound statement
      #|        └-[0]: return statement
      #|               └-additive expr: + (int)
      #|                 ├-variable a (int)
      #|                 └-variable b (int)
    ),
  )

  // Parse `int multiply(int x, int y);`
  let rest = next_check_point(rest)
  let (ext_decls, rest) = ctx.parse_external_declaration(rest)
  inspect(ext_decls.length(), content="1")
  inspect(
    ext_decls[0].to_string(color~),
    content="function declaration: int multiply(int x, int y)",
  )

  // Parse `int global_var;`
  let rest = next_check_point(rest)
  let (ext_decls, rest) = ctx.parse_external_declaration(rest)
  inspect(ext_decls.length(), content="1")
  inspect(
    ext_decls[0].to_string(color~),
    content="variable declaration: int global_var",
  )

  // Parse `static void helper() { return; }`
  let rest = next_check_point(rest)
  let (ext_decls, _rest) = ctx.parse_external_declaration(rest)
  inspect(ext_decls.length(), content="1")
  inspect(
    ext_decls[0].to_string(color~),
    content=(
      #|static function definition: helper () -> void
      #|└-body: compound statement
      #|        └-[0]: return statement (void)
    ),
  )
}

///|
test "External Declaration Parse Error Test" {
  // Error test: function definition missing body
  let code_err1 = "int add(int a, int b)"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_external_declaration(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: variable cannot have body
  let code_err2 = "int x {}"
  let ctx_err2 = Context::new(code=code_err2)
  let r = try? ctx_err2.parse_external_declaration(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: function with initializer
  let code_err3 = "int add(int a, int b) = 0 {}"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_external_declaration(ctx_err3.tokens)
  assert_true(r is Err(_))
}
