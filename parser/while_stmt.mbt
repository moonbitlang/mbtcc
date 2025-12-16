///|
///
/// While Statement
///
/// While 语句在条件为真时重复执行其主体语句。
///
/// ## Examples
///
/// ```c
/// while (i < 10) {
///     i++;
/// }
///
/// while (1) {
///     if (done) break;
/// }
/// ```
///
/// ## Grammar (EBNF)
///
/// iteration_statement
///   : WHILE '(' expression ')' statement
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_while_statement(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (WhileStmt, ArrayView[Token]) raise ParseError
/// ```
pub struct WhileStmt {
  cond : Expr
  body : Statement
  tokens : ArrayView[Token]
}

///|
pub impl Eq for WhileStmt with equal(self, other) {
  self.cond == other.cond && self.body == other.body
}

///|
pub impl Show for WhileStmt with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn WhileStmt::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = if color {
    @color.taint("while statement", Magenta)
  } else {
    "while statement"
  }
  let cond_str = self.cond.to_string(color~)
  let body_str = self.body.to_string(color~)
  let cond_lines = cond_str.split("\n")
  let cond_formatted = format_lines(
    cond_lines,
    head_with="├-cond: ",
    continue_with="│       ",
  )
  let body_lines = body_str.split("\n")
  let body_formatted = format_lines(
    body_lines,
    head_with="└-body: ",
    continue_with="        ",
  )
  "\{prefix}\n\{cond_formatted}\n\{body_formatted}"
}

///|
/// Parse a while statement from the given tokens.
///
/// Returns a tuple containing the parsed WhileStmt and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// while (i < 10) {
///     i++;
/// }
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "while (i < 10) i++;"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("i", CType::int())
/// let (while_stmt, rest) = ctx.parse_while_statement(ctx.tokens)
/// inspect(
///   while_stmt.to_string(color=false),
///   content=(
///     #|while statement
///     #|├-cond: relational expr: < (int)
///     #|│       ├-variable i (int)
///     #|│       └-int literal 10 (int)
///     #|└-body: expr statement
///     #|        └-unary operator ++ (int)
///     #|          └-variable i (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Missing '(' after 'while' keyword.
///
///    e.g.,
///    ```c
///    while i < 10) {}  // missing '('
///    ```
///
/// 2. Parse expression in condition fails.
///
///    e.g.,
///    ```c
///    while (?) {}  // invalid expression
///    ```
///
/// 3. Missing ')' after condition expression.
///
///    e.g.,
///    ```c
///    while (i < 10 {}  // missing ')'
///    ```
///
/// 4. Parse body statement fails.
///
///    e.g.,
///    ```c
///    while (i < 10) ?  // invalid statement
///    ```
pub fn Context::parse_while_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (WhileStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()

  // Parse 'while' keyword
  guard tokens is [{ kind: Keyword(While), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected 'while' keyword")
  }

  // Parse '('
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected '(' after 'while'")
  }

  // Parse condition expression
  let (cond, tokens) = self.parse_expr(tokens)

  // Parse ')'
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected ')' after while condition")
  }

  // Parse body statement
  let (body, tokens) = self.parse_statement(tokens)
  let while_stmt = WhileStmt::{
    cond,
    body,
    tokens: init_tokens[0:tokens.start_offset() - start_offset],
  }
  (while_stmt, tokens)
}

///|
test "While Statement Parse Test" {
  let color = false
  let code =
    #|while (i < 10) i++; ;
    #|while (1) { if (done) break; } ;
    #|while (x > 0) { x = x - 1; } ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("i", CType::int())
  ..add_var("done", CType::int())
  ..add_var("x", CType::int())

  // Parse `while (i < 10) i++;`
  let (while_stmt, rest) = ctx.parse_while_statement(ctx.tokens)
  inspect(
    while_stmt.to_string(color~),
    content=(
      #|while statement
      #|├-cond: relational expr: < (int)
      #|│       ├-variable i (int)
      #|│       └-int literal 10 (int)
      #|└-body: expr statement
      #|        └-unary operator ++ (int)
      #|          └-variable i (int)
    ),
  )
  assert_true(
    ctx.parse_while_statement(while_stmt.tokens) is (re_while_stmt, re_rest) &&
    re_while_stmt == while_stmt &&
    re_rest is [],
  )

  // Parse `while (1) { if (done) break; }`
  let rest = next_check_point(rest)
  let (while_stmt, rest) = ctx.parse_while_statement(rest)
  inspect(
    while_stmt.to_string(color~),
    content=(
      #|while statement
      #|├-cond: int literal 1 (int)
      #|└-body: compound_statement
      #|        └-[0]: if statement
      #|               ├-cond: variable done (int)
      #|               └-then: break statement
    ),
  )
  assert_true(
    ctx.parse_while_statement(while_stmt.tokens) is (re_while_stmt, re_rest) &&
    re_while_stmt == while_stmt &&
    re_rest is [],
  )

  // Parse `while (x > 0) { x = x - 1; }`
  let rest = next_check_point(rest)
  let (while_stmt, _rest) = ctx.parse_while_statement(rest)
  inspect(
    while_stmt.to_string(color~),
    content=(
      #|while statement
      #|├-cond: relational expr: > (int)
      #|│       ├-variable x (int)
      #|│       └-int literal 0 (int)
      #|└-body: compound_statement
      #|        └-[0]: expr statement
      #|               └-assignment expr: = (int)
      #|                 ├-lvalue: variable x (int)
      #|                 └-rvalue: additive expr: - (int)
      #|                           ├-variable x (int)
      #|                           └-int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_while_statement(while_stmt.tokens) is (re_while_stmt, re_rest) &&
    re_while_stmt == while_stmt &&
    re_rest is [],
  )
}

///|
test "While Statement Parse Error Test" {
  // Error test: missing '(' after 'while'
  let code_err1 = "while i < 10) {}"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_while_statement(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: missing ')' after condition
  let code_err2 = "while (i < 10 {}"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  let r = try? ctx_err2.parse_while_statement(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: invalid expression in condition
  let code_err3 = "while (?) {}"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_while_statement(ctx_err3.tokens)
  assert_true(r is Err(_))
}
