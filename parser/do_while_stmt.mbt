///|
///
/// Do-While Statement
///
/// do-while 语句至少执行一次主体，再在末尾检查条件决定是否继续。
///
/// ## Examples
///
/// ```c
/// do {
///     i++;
/// } while (i < 10);
///
/// do {
///     sum = sum + i;
///     i++;
/// } while (i < n);
/// ```
///
/// ## Grammar (EBNF)
///
/// iteration_statement
///   : DO statement WHILE '(' expression ')' ';'
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_do_while_statement(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (DoWhileStmt, ArrayView[Token]) raise ParseError
/// ```
pub struct DoWhileStmt {
  body : Statement
  cond : Expr
  tokens : ArrayView[Token]
}

///|
pub impl Eq for DoWhileStmt with equal(self, other) {
  self.body == other.body && self.cond == other.cond
}

///|
pub impl Show for DoWhileStmt with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn DoWhileStmt::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = if color {
    @color.taint("do-while statement", Magenta)
  } else {
    "do-while statement"
  }
  let body_str = self.body.to_string(color~)
  let cond_str = self.cond.to_string(color~)
  let body_lines = body_str.split("\n").to_array().iterator()
  let body_formatted = format_lines(
    body_lines,
    head_with="├-body: ",
    continue_with="│       ",
  )
  let cond_lines = cond_str.split("\n").to_array().iterator()
  let cond_formatted = format_lines(
    cond_lines,
    head_with="└-cond: ",
    continue_with="        ",
  )
  "\{prefix}\n\{body_formatted}\n\{cond_formatted}"
}

///|
/// ## Example Parse:
///
/// ```c
/// do i++; while (i < 10);
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "do i++; while (i < 10);"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("i", CType::int())
/// let (do_while_stmt, rest) = ctx.parse_do_while_statement(ctx.tokens)
/// inspect(
///   do_while_stmt.to_string(color=false),
///   content=(
///     #|do-while statement
///     #|├-body: expr statement
///     #|│       └-unary operator ++ (int)
///     #|│         └-variable i (int)
///     #|└-cond: relational expr: < (int)
///     #|        ├-variable i (int)
///     #|        └-int literal 10 (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Missing 'while' keyword after body statement.
///
///    e.g.,
///    ```c
///    do { i++; } if (i < 10);  // should be 'while'
///    ```
///
/// 2. Missing '(' after 'while'.
///
///    e.g.,
///    ```c
///    do i++; while i < 10);  // missing '('
///    ```
///
/// 3. Missing ')' after condition expression.
///
///    e.g.,
///    ```c
///    do i++; while (i < 10;  // missing ')'
///    ```
///
/// 4. Missing ';' terminator.
///
///    e.g.,
///    ```c
///    do i++; while (i < 10)  // missing ';'
///    ```
pub fn Context::parse_do_while_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (DoWhileStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()

  // Parse 'do' keyword
  guard tokens is [{ kind: Keyword(Do), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected 'do' keyword")
  }

  // Parse body statement
  let (body, tokens) = self.parse_statement(tokens)

  // Parse 'while' keyword
  guard tokens is [{ kind: Keyword(While), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected 'while' after do statement body")
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

  // Parse ';'
  guard tokens is [{ kind: Semi, .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected ';' after do-while statement")
  }
  let do_while_stmt = DoWhileStmt::{
    body,
    cond,
    tokens: init_tokens[0:tokens.start_offset() - start_offset],
  }
  (do_while_stmt, tokens)
}

///|
test "Do-While Statement Parse Test" {
  let color = false
  let code =
    #|do i++; while (i < 10); ;
    #|do { sum = sum + i; i++; } while (i < n); ;
  let ctx = Context::new(code~, source_file="demo")
  ctx
  ..add_var("i", CType::int())
  ..add_var("sum", CType::int())
  ..add_var("n", CType::int())

  // Parse `do i++; while (i < 10);`
  let (do_while_stmt, rest) = ctx.parse_do_while_statement(ctx.tokens)
  inspect(
    do_while_stmt.to_string(color~),
    content=(
      #|do-while statement
      #|├-body: expr statement
      #|│       └-unary operator ++ (int)
      #|│         └-variable i (int)
      #|└-cond: relational expr: < (int)
      #|        ├-variable i (int)
      #|        └-int literal 10 (int)
    ),
  )
  assert_true(
    ctx.parse_do_while_statement(do_while_stmt.tokens)
    is (re_do_while_stmt, re_rest) &&
    re_do_while_stmt == do_while_stmt &&
    re_rest is [],
  )

  // Parse `do { sum = sum + i; i++; } while (i < n);`
  let rest = next_check_point(rest)
  let (do_while_stmt, _rest) = ctx.parse_do_while_statement(rest)
  inspect(
    do_while_stmt.to_string(color~),
    content=(
      #|do-while statement
      #|├-body: compound_statement
      #|│       ├-[0]: expr statement
      #|│       |      └-assignment expr: = (int)
      #|│       |        ├-lvalue: variable sum (int)
      #|│       |        └-rvalue: additive expr: + (int)
      #|│       |                  ├-variable sum (int)
      #|│       |                  └-variable i (int)
      #|│       └-[1]: expr statement
      #|│              └-unary operator ++ (int)
      #|│                └-variable i (int)
      #|└-cond: relational expr: < (int)
      #|        ├-variable i (int)
      #|        └-variable n (int)
    ),
  )
  assert_true(
    ctx.parse_do_while_statement(do_while_stmt.tokens)
    is (re_do_while_stmt, re_rest) &&
    re_do_while_stmt == do_while_stmt &&
    re_rest is [],
  )
}

///|
test "Do-While Statement Parse Error Test" {
  // Error test: missing 'while' keyword
  let code_err1 = "do { i++; } if (i < 10);"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_do_while_statement(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: missing ';'
  let code_err2 = "do { i++; } while (i < 10)"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  let r = try? ctx_err2.parse_do_while_statement(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: missing '('
  let code_err3 = "do i++; while i < 10);"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_do_while_statement(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: missing ')'
  let code_err4 = "do i++; while (i < 10;"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("i", CType::int())
  let r = try? ctx_err4.parse_do_while_statement(ctx_err4.tokens)
  assert_true(r is Err(_))
}
