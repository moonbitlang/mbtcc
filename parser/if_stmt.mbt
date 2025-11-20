///|
///
/// If Statement
///
/// If statements are selection statements that conditionally execute 
/// a statement based on the evaluation of an expression. They support 
/// optional else clauses.
///
/// ## Examples
///
/// ```c
/// if (x > 0) {
///     printf("positive");
/// }
///
/// if (x == 0) {
///     printf("zero");
/// } else {
///     printf("non-zero");
/// }
///
/// if (x > 0)
///     return 1;
/// else if (x < 0)
///     return -1;
/// else
///     return 0;
/// ```
///
/// ## Grammar (EBNF)
///
/// selection_statement
///   : IF '(' expression ')' statement
///   | IF '(' expression ')' statement ELSE statement
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_if_statement(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (IfStmt, ArrayView[Token]) raise ParseError
/// ```
pub struct IfStmt {
  cond : Expr
  then_stmt : Statement
  else_stmt : Statement?
  tokens : ArrayView[Token]
}

///|
pub impl Eq for IfStmt with equal(self, other) {
  self.cond == other.cond &&
  self.then_stmt == other.then_stmt &&
  self.else_stmt == other.else_stmt
}

///|
pub impl Show for IfStmt with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn IfStmt::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = if color {
    @color.taint("if statement", Magenta)
  } else {
    "if statement"
  }
  let cond_str = self.cond.to_string(color~)
  let then_str = self.then_stmt.to_string(color~)
  let cond_lines = cond_str.split("\n")
  let cond_formatted = format_lines(
    cond_lines,
    head_with="├-cond: ",
    continue_with="│       ",
  )
  let result = match self.else_stmt {
    None => {
      let then_lines = then_str.split("\n")
      let then_formatted = format_lines(
        then_lines,
        head_with="└-then: ",
        continue_with="        ",
      )
      "\{prefix}\n\{cond_formatted}\n\{then_formatted}"
    }
    Some(else_stmt) => {
      let then_lines = then_str.split("\n")
      let then_formatted = format_lines(
        then_lines,
        head_with="├-then: ",
        continue_with="│       ",
      )
      let else_str = else_stmt.to_string(color~)
      let else_lines = else_str.split("\n")
      let else_formatted = format_lines(
        else_lines,
        head_with="└-else: ",
        continue_with="        ",
      )
      "\{prefix}\n\{cond_formatted}\n\{then_formatted}\n\{else_formatted}"
    }
  }
  result
}

///|
/// Parse an if statement from the given tokens.
///
/// Returns a tuple containing the parsed IfStmt and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// if (x > 0) {
///     return x;
/// }
///
/// if (x == 0) {
///     return 0;
/// } else {
///     return 1;
/// }
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "if (x > 0) return x;"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// let (if_stmt, rest) = ctx.parse_if_statement(ctx.tokens)
/// inspect(
///   if_stmt.to_string(color=false),
///   content=(
///     #|if statement
///     #|├-cond: relational expr: > (int)
///     #|│       ├-variable x (int)
///     #|│       └-int literal 0 (int)
///     #|└-then: return statement
///     #|        └-variable x (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Missing '(' after 'if' keyword.
///
///    e.g.,
///    ```c
///    if x > 0) {}  // missing '('
///    ```
///
/// 2. Parse expression in condition fails.
///
///    e.g.,
///    ```c
///    if (?) {}  // invalid expression
///    ```
///
/// 3. Missing ')' after condition expression.
///
///    e.g.,
///    ```c
///    if (x > 0 {}  // missing ')'
///    ```
///
/// 4. Parse then statement fails.
///
///    e.g.,
///    ```c
///    if (x > 0) ?  // invalid statement
///    ```
///
/// 5. Parse else statement fails (when else is present).
///
///    e.g.,
///    ```c
///    if (x > 0) return x; else ?  // invalid statement after else
///    ```
pub fn Context::parse_if_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (IfStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()

  // Parse 'if' keyword
  guard tokens is [{ kind: Keyword(If), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected 'if' keyword")
  }

  // Parse '('
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected '(' after 'if'")
  }

  // Parse condition expression
  let (cond, tokens) = self.parse_expr(tokens)

  // Parse ')'
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected ')' after if condition")
  }

  // Parse then statement
  let (then_stmt, tokens) = self.parse_statement(tokens)

  // Check for else clause
  let (else_stmt, tokens) = if tokens
    is [{ kind: Keyword(Else), .. }, .. tokens] {
    let (else_stmt, tokens) = self.parse_statement(tokens)
    (Some(else_stmt), tokens)
  } else {
    (None, tokens)
  }
  let if_stmt = IfStmt::{
    cond,
    then_stmt,
    else_stmt,
    tokens: init_tokens[0:tokens.start_offset() - start_offset],
  }
  (if_stmt, tokens)
}

///|
test "If Statement Parse Test" {
  let color = false
  let code =
    #|if (x > 0) return x; ;
    #|if (x == 0) return 0; else return 1; ;
    #|if (flag) { x = 1; } else { x = 0; } ;
    #|if (a > b) if (a > c) return a; else return c; ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("x", CType::int())
  ..add_var("flag", CType::int())
  ..add_var("a", CType::int())
  ..add_var("b", CType::int())
  ..add_var("c", CType::int())

  // Parse `if (x > 0) return x;`
  let (if_stmt, rest) = ctx.parse_if_statement(ctx.tokens)
  inspect(
    if_stmt.to_string(color~),
    content=(
      #|if statement
      #|├-cond: relational expr: > (int)
      #|│       ├-variable x (int)
      #|│       └-int literal 0 (int)
      #|└-then: return statement
      #|        └-variable x (int)
    ),
  )
  assert_true(
    ctx.parse_if_statement(if_stmt.tokens) is (re_if_stmt, re_rest) &&
    re_if_stmt == if_stmt &&
    re_rest is [],
  )

  // Parse `if (x == 0) return 0; else return 1;`
  let rest = next_check_point(rest)
  let (if_stmt, rest) = ctx.parse_if_statement(rest)
  inspect(
    if_stmt.to_string(color~),
    content=(
      #|if statement
      #|├-cond: equality expr: == (int)
      #|│       ├-variable x (int)
      #|│       └-int literal 0 (int)
      #|├-then: return statement
      #|│       └-int literal 0 (int)
      #|└-else: return statement
      #|        └-int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_if_statement(if_stmt.tokens) is (re_if_stmt, re_rest) &&
    re_if_stmt == if_stmt &&
    re_rest is [],
  )

  // Parse `if (flag) { x = 1; } else { x = 0; }`
  let rest = next_check_point(rest)
  let (if_stmt, rest) = ctx.parse_if_statement(rest)
  inspect(
    if_stmt.to_string(color~),
    content=(
      #|if statement
      #|├-cond: variable flag (int)
      #|├-then: compound statement
      #|│       └-[0]: expr statement
      #|│              └-assignment expr: = (int)
      #|│                ├-lvalue: variable x (int)
      #|│                └-rvalue: int literal 1 (int)
      #|└-else: compound statement
      #|        └-[0]: expr statement
      #|               └-assignment expr: = (int)
      #|                 ├-lvalue: variable x (int)
      #|                 └-rvalue: int literal 0 (int)
    ),
  )
  assert_true(
    ctx.parse_if_statement(if_stmt.tokens) is (re_if_stmt, re_rest) &&
    re_if_stmt == if_stmt &&
    re_rest is [],
  )

  // Parse `if (a > b) if (a > c) return a; else return c;` (nested if-else)
  let rest = next_check_point(rest)
  let (if_stmt, _rest) = ctx.parse_if_statement(rest)
  inspect(
    if_stmt.to_string(color~),
    content=(
      #|if statement
      #|├-cond: relational expr: > (int)
      #|│       ├-variable a (int)
      #|│       └-variable b (int)
      #|└-then: if statement
      #|        ├-cond: relational expr: > (int)
      #|        │       ├-variable a (int)
      #|        │       └-variable c (int)
      #|        ├-then: return statement
      #|        │       └-variable a (int)
      #|        └-else: return statement
      #|                └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_if_statement(if_stmt.tokens) is (re_if_stmt, re_rest) &&
    re_if_stmt == if_stmt &&
    re_rest is [],
  )
}

///|
test "If Statement Parse Error Test" {
  // Error test: missing '(' after 'if'
  let code_err1 = "if x > 0) {}"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("x", CType::int())
  let r = try? ctx_err1.parse_if_statement(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: missing ')' after condition
  let code_err2 = "if (x > 0 {}"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("x", CType::int())
  let r = try? ctx_err2.parse_if_statement(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: invalid expression in condition
  let code_err3 = "if (?) {}"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_if_statement(ctx_err3.tokens)
  assert_true(r is Err(_))
}
