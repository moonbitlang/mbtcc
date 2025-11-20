///|
///
/// For Statement
///
/// For statements are iteration statements that provide a compact way 
/// to iterate with initialization, condition, and increment/update.
/// They support both expression-based and declaration-based initialization.
///
/// ## Examples
///
/// ```c
/// for (i = 0; i < 10; i++) {
///     sum += i;
/// }
///
/// for (int i = 0; i < 10; i++) {
///     printf("%d\n", i);
/// }
///
/// for (;;) {
///     if (done) break;
/// }
///
/// for (i = 0, j = 0; i < 10; i++, j++) {
///     arr[i] = j;
/// }
/// ```
///
/// ## Grammar (EBNF)
///
/// iteration_statement
///   : FOR '(' expression_statement expression_statement ')' statement
///   | FOR '(' expression_statement expression_statement expression ')' statement
///   | FOR '(' declaration expression_statement ')' statement
///   | FOR '(' declaration expression_statement expression ')' statement
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_for_statement(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (ForStmt, ArrayView[Token]) raise ParseError
/// ```
pub struct ForStmt {
  init : ForInit?
  cond : Expr?
  update : Expr?
  body : Statement
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ForStmt with equal(self, other) {
  self.init == other.init &&
  self.cond == other.cond &&
  self.update == other.update &&
  self.body == other.body
}

///|
pub enum ForInit {
  Expr(Expr)
  Declaration(Array[Declaration])
} derive(Eq)

///|
pub impl Show for ForStmt with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn ForStmt::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = if color {
    @color.taint("for statement", Magenta)
  } else {
    "for statement"
  }
  let mut result = prefix

  // Format init clause
  match self.init {
    None => result = result + "\n├-init: (none)"
    Some(Expr(expr)) => {
      let init_str = expr.to_string(color~)
      let init_lines = init_str.split("\n")
      let init_formatted = format_lines(
        init_lines,
        head_with="├-init: ",
        continue_with="│       ",
      )
      result = result + "\n" + init_formatted
    }
    Some(Declaration(decls)) => {
      result = result + "\n├-init: (declaration)"
      for i, decl in decls {
        let decl_str = decl.to_string(color~)
        let decl_lines = decl_str.split("\n")
        let is_last = i == decls.length() - 1
        // Use consistent indentation
        let decl_formatted = if is_last {
          format_lines(
            decl_lines,
            head_with="│  └-[\{i}]: ",
            continue_with="│       ",
          )
        } else {
          format_lines(
            decl_lines,
            head_with="│  ├-[\{i}]: ",
            continue_with="│  │    ",
          )
        }
        result = result + "\n" + decl_formatted
      }
    }
  }

  // Format condition clause
  match self.cond {
    None => {
      let prefix_cond = if self.update is None {
        "├-cond: (none)"
      } else {
        "├-cond: (none)"
      }
      result = result + "\n" + prefix_cond
    }
    Some(cond) => {
      let cond_str = cond.to_string(color~)
      let cond_lines = cond_str.split("\n")
      let cond_formatted = format_lines(
        cond_lines,
        head_with="├-cond: ",
        continue_with="│       ",
      )
      result = result + "\n" + cond_formatted
    }
  }

  // Format update clause
  match self.update {
    None => result = result + "\n├-update: (none)"
    Some(update) => {
      let update_str = update.to_string(color~)
      let update_lines = update_str.split("\n")
      let update_formatted = format_lines(
        update_lines,
        head_with="├-update: ",
        continue_with="│         ",
      )
      result = result + "\n" + update_formatted
    }
  }

  // Format body
  let body_str = self.body.to_string(color~)
  let body_lines = body_str.split("\n")
  let body_formatted = format_lines(
    body_lines,
    head_with="└-body: ",
    continue_with="        ",
  )
  result = result + "\n" + body_formatted
  result
}

///|
/// Parse a for statement from the given tokens.
///
/// Returns a tuple containing the parsed ForStmt and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// for (i = 0; i < 10; i++) {
///     sum += i;
/// }
///
/// for (int i = 0; i < 10; i++) {
///     printf("%d\n", i);
/// }
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "for (i = 0; i < 10; i++) sum = sum + i;"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx..add_var("i", CType::int())..add_var("sum", CType::int())
/// let (for_stmt, rest) = ctx.parse_for_statement(ctx.tokens)
/// inspect(
///   for_stmt.to_string(color=false),
///   content=(
///     
///   #|for statement
/// #|├-init: assignment expr: = (int)
/// #|│       ├-lvalue: variable i (int)
/// #|│       └-rvalue: int literal 0 (int)
/// #|├-cond: relational expr: < (int)
/// #|│       ├-variable i (int)
/// #|│       └-int literal 10 (int)
/// #|├-update: unary operator ++ (int)
/// #|│         └-variable i (int)
/// #|└-body: expr statement
/// #|        └-assignment expr: = (int)
/// #|          ├-lvalue: variable sum (int)
/// #|          └-rvalue: additive expr: + (int)
/// #|                    ├-variable sum (int)
/// #|                    └-variable i (int)
/// 
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Missing '(' after 'for' keyword.
///
///    e.g.,
///    ```c
///    for i = 0; i < 10; i++) {}  // missing '('
///    ```
///
/// 2. Parse initialization fails.
///
///    e.g.,
///    ```c
///    for (?; i < 10; i++) {}  // invalid initialization
///    ```
///
/// 3. Parse condition fails.
///
///    e.g.,
///    ```c
///    for (i = 0; ?; i++) {}  // invalid condition
///    ```
///
/// 4. Parse update expression fails.
///
///    e.g.,
///    ```c
///    for (i = 0; i < 10; ?) {}  // invalid update expression
///    ```
///
/// 5. Missing ')' after for clauses.
///
///    e.g.,
///    ```c
///    for (i = 0; i < 10; i++ {}  // missing ')'
///    ```
///
/// 6. Parse body statement fails.
///
///    e.g.,
///    ```c
///    for (i = 0; i < 10; i++) ?  // invalid statement
///    ```
pub fn Context::parse_for_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (ForStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()

  // Parse 'for' keyword
  guard tokens is [{ kind: Keyword(For), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected 'for' keyword")
  }

  // Parse '('
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected '(' after 'for'")
  }

  // Parse initialization clause
  // This can be either:
  // 1. A declaration (e.g., int i = 0;)
  // 2. An expression statement (e.g., i = 0;)
  // 3. Just a semicolon (empty initialization)
  let (init, tokens) = if tokens is [tok, ..] && self.is_type_tok(tok) {
    // Declaration-based initialization
    let (decls, tokens) = self.parse_declaration(tokens)
    (Some(ForInit::Declaration(decls)), tokens)
  } else if tokens is [{ kind: Semi, .. }, .. tokens] {
    // Empty initialization
    (None, tokens)
  } else {
    // Expression-based initialization
    let (expr, tokens) = self.parse_expr(tokens)
    guard tokens is [{ kind: Semi, .. }, .. tokens] else {
      raise ParseError(tokens[0], "Expected ';' after for initialization")
    }
    (Some(ForInit::Expr(expr)), tokens)
  }

  // Parse condition clause
  let (cond, tokens) = if tokens is [{ kind: Semi, .. }, .. tokens] {
    // Empty condition (infinite loop)
    (None, tokens)
  } else {
    let (expr, tokens) = self.parse_expr(tokens)
    guard tokens is [{ kind: Semi, .. }, .. tokens] else {
      raise ParseError(tokens[0], "Expected ';' after for condition")
    }
    (Some(expr), tokens)
  }

  // Parse update clause
  let (update, tokens) = if tokens is [{ kind: Bracket(')'), .. }, .. tokens] {
    // Empty update clause
    (None, tokens)
  } else {
    let (expr, tokens) = self.parse_expr(tokens)
    guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
      raise ParseError(tokens[0], "Expected ')' after for update expression")
    }
    (Some(expr), tokens)
  }

  // Parse body statement
  let (body, tokens) = self.parse_statement(tokens)
  let for_stmt = ForStmt::{
    init,
    cond,
    update,
    body,
    tokens: init_tokens[0:tokens.start_offset() - start_offset],
  }
  (for_stmt, tokens)
}

///|
test "For Statement Parse Test" {
  let color = false
  let code =
    #|for (i = 0; i < 10; i++) sum = sum + i; ;
    #|for (;;) { if (done) break; } ;
    #|for (i = 0; i < n; ) { i = i + 1; } ;
    #|for (; i < 10; i++) { sum = sum + i; } ;
    #|for (int i = 0; i < 10; i++) sum = sum + i; ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("i", CType::int())
  ..add_var("sum", CType::int())
  ..add_var("done", CType::int())
  ..add_var("n", CType::int())

  // Parse `for (i = 0; i < 10; i++) sum = sum + i;`
  let (for_stmt, rest) = ctx.parse_for_statement(ctx.tokens)
  inspect(
    for_stmt.to_string(color~),
    content=(
      #|for statement
      #|├-init: assignment expr: = (int)
      #|│       ├-lvalue: variable i (int)
      #|│       └-rvalue: int literal 0 (int)
      #|├-cond: relational expr: < (int)
      #|│       ├-variable i (int)
      #|│       └-int literal 10 (int)
      #|├-update: unary operator ++ (int)
      #|│         └-variable i (int)
      #|└-body: expr statement
      #|        └-assignment expr: = (int)
      #|          ├-lvalue: variable sum (int)
      #|          └-rvalue: additive expr: + (int)
      #|                    ├-variable sum (int)
      #|                    └-variable i (int)
    ),
  )
  assert_true(
    ctx.parse_for_statement(for_stmt.tokens) is (re_for_stmt, re_rest) &&
    re_for_stmt == for_stmt &&
    re_rest is [],
  )

  // Parse `for (;;) { if (done) break; }`
  let rest = next_check_point(rest)
  let (for_stmt, rest) = ctx.parse_for_statement(rest)
  inspect(
    for_stmt.to_string(color~),
    content=(
      #|for statement
      #|├-init: (none)
      #|├-cond: (none)
      #|├-update: (none)
      #|└-body: compound statement
      #|        └-[0]: if statement
      #|               ├-cond: variable done (int)
      #|               └-then: break statement
    ),
  )
  assert_true(
    ctx.parse_for_statement(for_stmt.tokens) is (re_for_stmt, re_rest) &&
    re_for_stmt == for_stmt &&
    re_rest is [],
  )

  // Parse `for (i = 0; i < n; ) { i = i + 1; }`
  let rest = next_check_point(rest)
  let (for_stmt, rest) = ctx.parse_for_statement(rest)
  inspect(
    for_stmt.to_string(color~),
    content=(
      #|for statement
      #|├-init: assignment expr: = (int)
      #|│       ├-lvalue: variable i (int)
      #|│       └-rvalue: int literal 0 (int)
      #|├-cond: relational expr: < (int)
      #|│       ├-variable i (int)
      #|│       └-variable n (int)
      #|├-update: (none)
      #|└-body: compound statement
      #|        └-[0]: expr statement
      #|               └-assignment expr: = (int)
      #|                 ├-lvalue: variable i (int)
      #|                 └-rvalue: additive expr: + (int)
      #|                           ├-variable i (int)
      #|                           └-int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_for_statement(for_stmt.tokens) is (re_for_stmt, re_rest) &&
    re_for_stmt == for_stmt &&
    re_rest is [],
  )

  // Parse `for (; i < 10; i++) { sum = sum + i; }`
  let rest = next_check_point(rest)
  let (for_stmt, rest) = ctx.parse_for_statement(rest)
  inspect(
    for_stmt.to_string(color~),
    content=(
      #|for statement
      #|├-init: (none)
      #|├-cond: relational expr: < (int)
      #|│       ├-variable i (int)
      #|│       └-int literal 10 (int)
      #|├-update: unary operator ++ (int)
      #|│         └-variable i (int)
      #|└-body: compound statement
      #|        └-[0]: expr statement
      #|               └-assignment expr: = (int)
      #|                 ├-lvalue: variable sum (int)
      #|                 └-rvalue: additive expr: + (int)
      #|                           ├-variable sum (int)
      #|                           └-variable i (int)
    ),
  )
  assert_true(
    ctx.parse_for_statement(for_stmt.tokens) is (re_for_stmt, re_rest) &&
    re_for_stmt == for_stmt &&
    re_rest is [],
  )

  // Parse `for (int j = 0; j < 10; j++) sum = sum + j;`
  let _rest = next_check_point(rest)
  let code_for_decl = "for (int j = 0; j < 10; j++) sum = sum + j; ;"
  let ctx_for_decl = Context::new(code=code_for_decl)
  ctx_for_decl..add_var("sum", CType::int())
  let (for_stmt, _rest) = ctx_for_decl.parse_for_statement(ctx_for_decl.tokens)
  inspect(
    for_stmt.to_string(color~),
    content=(
      #|for statement
      #|├-init: (declaration)
      #|│  └-[0]: variable declaration: int j
      #|│       └-int literal 0 (int)
      #|├-cond: relational expr: < (int)
      #|│       ├-variable j (int)
      #|│       └-int literal 10 (int)
      #|├-update: unary operator ++ (int)
      #|│         └-variable j (int)
      #|└-body: expr statement
      #|        └-assignment expr: = (int)
      #|          ├-lvalue: variable sum (int)
      #|          └-rvalue: additive expr: + (int)
      #|                    ├-variable sum (int)
      #|                    └-variable j (int)
    ),
  )
  // Create a new context for re-parsing to avoid redeclaration
  let ctx_reparse = Context::new(code=code_for_decl)
  ctx_reparse.add_var("sum", CType::int())
  assert_true(
    ctx_reparse.parse_for_statement(for_stmt.tokens) is (re_for_stmt, re_rest) &&
    re_for_stmt == for_stmt &&
    re_rest is [],
  )
}

///|
test "For Statement Parse Error Test" {
  // Error test: missing '(' after 'for'
  let code_err1 = "for i = 0; i < 10; i++) {}"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_for_statement(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: missing ')' after for clauses
  let code_err2 = "for (i = 0; i < 10; i++ {}"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  let r = try? ctx_err2.parse_for_statement(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: invalid expression in condition
  let code_err3 = "for (i = 0; ?; i++) {}"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_for_statement(ctx_err3.tokens)
  assert_true(r is Err(_))
}
