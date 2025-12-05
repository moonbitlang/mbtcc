///|
///
/// Switch Statement
///
/// Switch statements are selection statements that transfer control 
/// to one of several statements based on the value of an expression.
/// They use case labels to mark potential entry points.
///
/// ## Examples
///
/// ```c
/// switch (x) {
///     case 1:
///         printf("one");
///         break;
///     case 2:
///         printf("two");
///         break;
///     default:
///         printf("other");
/// }
///
/// switch (ch) {
///     case 'a':
///     case 'e':
///     case 'i':
///     case 'o':
///     case 'u':
///         printf("vowel");
///         break;
///     default:
///         printf("consonant");
/// }
/// ```
///
/// ## Grammar (EBNF)
///
/// selection_statement
///   : SWITCH '(' expression ')' statement
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_switch_statement(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (SwitchStmt, ArrayView[Token]) raise ParseError
/// ```
pub struct SwitchStmt {
  expr : Expr
  body : Statement
  tokens : ArrayView[Token]
}

///|
pub impl Eq for SwitchStmt with equal(self, other) {
  self.expr == other.expr && self.body == other.body
}

///|
pub impl Show for SwitchStmt with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn SwitchStmt::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = if color {
    @color.taint("switch statement", Magenta)
  } else {
    "switch statement"
  }
  let expr_str = self.expr.to_string(color~)
  let body_str = self.body.to_string(color~)
  let expr_lines = expr_str.split("\n")
  let expr_formatted = format_lines(
    expr_lines,
    head_with="├-expr: ",
    continue_with="│       ",
  )
  let body_lines = body_str.split("\n")
  let body_formatted = format_lines(
    body_lines,
    head_with="└-body: ",
    continue_with="        ",
  )
  "\{prefix}\n\{expr_formatted}\n\{body_formatted}"
}

///|
/// Parse a switch statement from the given tokens.
///
/// Returns a tuple containing the parsed SwitchStmt and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// switch (x) {
///     case 1:
///         return 1;
///     case 2:
///         return 2;
///     default:
///         return 0;
/// }
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "switch (x) { case 1: return 1; default: return 0; }"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// let (switch_stmt, rest) = ctx.parse_switch_statement(ctx.tokens)
/// inspect(
///   switch_stmt.to_string(color=false),
///   content=(
///     
///   
///   
///   
///   #|switch statement
/// #|├-expr: variable x (int)
/// #|└-body: compound_statement
/// #|        ├-[0]: case statement
/// #|        |      ├-value: int literal 1 (int)
/// #|        |      └-stmt: return statement
/// #|        |              └-int literal 1 (int)
/// #|        └-[1]: default case statement
/// #|               └-stmt: return statement
/// #|                       └-int literal 0 (int)
///
///
///
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
/// 1. Missing '(' after 'switch' keyword.
///
///    e.g.,
///    ```c
///    switch x) {}  // missing '('
///    ```
///
/// 2. Parse expression fails.
///
///    e.g.,
///    ```c
///    switch (?) {}  // invalid expression
///    ```
///
/// 3. Missing ')' after expression.
///
///    e.g.,
///    ```c
///    switch (x {}  // missing ')'
///    ```
///
/// 4. Parse body statement fails.
///
///    e.g.,
///    ```c
///    switch (x) ?  // invalid statement
///    ```
pub fn Context::parse_switch_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (SwitchStmt, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()

  // Parse 'switch' keyword
  guard tokens is [{ kind: Keyword(Switch), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected 'switch' keyword")
  }

  // Parse '('
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected '(' after 'switch'")
  }

  // Parse expression
  let (expr, tokens) = self.parse_expr(tokens)

  // Parse ')'
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    raise ParseError(tokens[0], "Expected ')' after switch expression")
  }

  // Parse body statement (typically a compound statement with case labels)
  let (body, tokens) = self.parse_statement(tokens)
  let switch_stmt = SwitchStmt::{
    expr,
    body,
    tokens: init_tokens[0:tokens.start_offset() - start_offset],
  }
  (switch_stmt, tokens)
}

///|
test "Switch Statement Parse Test" {
  let color = false
  let code =
    #|switch (x) { case 1: return 1; default: return 0; } ;
    #|switch (ch) { case 'a': case 'e': printf("vowel"); break; default: break; } ;
    #|switch (n) { case 0: x = 0; break; case 1: x = 1; break; case 2: x = 2; break; } ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("x", CType::int())
  ..add_var("ch", CType::char())
  ..add_var("n", CType::int())

  // Parse `switch (x) { case 1: return 1; default: return 0; }`
  let (switch_stmt, _rest) = ctx.parse_switch_statement(ctx.tokens)
  inspect(
    switch_stmt.to_string(color~),
    content=(
      #|switch statement
      #|├-expr: variable x (int)
      #|└-body: compound_statement
      #|        ├-[0]: case statement
      #|        |      ├-value: int literal 1 (int)
      #|        |      └-stmt: return statement
      #|        |              └-int literal 1 (int)
      #|        └-[1]: default case statement
      #|               └-stmt: return statement
      #|                       └-int literal 0 (int)
    ),
  )
  assert_true(
    ctx.parse_switch_statement(switch_stmt.tokens) is (re_switch_stmt, re_rest) &&
    re_switch_stmt == switch_stmt &&
    re_rest is [],
  )

  // Parse `switch (ch) { case 'a': case 'e': printf("vowel"); break; default: break; }`
  // Note: printf is not implemented, so we expect this to fail during parsing
  // Let's use a simpler version for testing
  let code2 = "switch (ch) { case 'a': case 'e': x = 1; break; default: break; } ;"
  let ctx2 = Context::new(code=code2)
  ctx2..add_var("ch", CType::char())..add_var("x", CType::int())
  let (switch_stmt, rest) = ctx2.parse_switch_statement(ctx2.tokens)
  inspect(
    switch_stmt.to_string(color~),
    content=(
      #|switch statement
      #|├-expr: variable ch (char)
      #|└-body: compound_statement
      #|        ├-[0]: case statement
      #|        |      ├-value: char literal 'a' (char)
      #|        |      └-stmt: case statement
      #|        |              ├-value: char literal 'e' (char)
      #|        |              └-stmt: expr statement
      #|        |                      └-assignment expr: = (int)
      #|        |                        ├-lvalue: variable x (int)
      #|        |                        └-rvalue: int literal 1 (int)
      #|        ├-[1]: break statement
      #|        └-[2]: default case statement
      #|               └-stmt: break statement
    ),
  )
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])

  // Parse `switch (n) { case 0: x = 0; break; case 1: x = 1; break; case 2: x = 2; break; }`
  let code3 = "switch (n) { case 0: x = 0; break; case 1: x = 1; break; case 2: x = 2; break; }"
  let ctx3 = Context::new(code=code3)
  ctx3..add_var("n", CType::int())..add_var("x", CType::int())
  let (switch_stmt, _rest) = ctx3.parse_switch_statement(ctx3.tokens)
  inspect(
    switch_stmt.to_string(color~),
    content=(
      #|switch statement
      #|├-expr: variable n (int)
      #|└-body: compound_statement
      #|        ├-[0]: case statement
      #|        |      ├-value: int literal 0 (int)
      #|        |      └-stmt: expr statement
      #|        |              └-assignment expr: = (int)
      #|        |                ├-lvalue: variable x (int)
      #|        |                └-rvalue: int literal 0 (int)
      #|        ├-[1]: break statement
      #|        ├-[2]: case statement
      #|        |      ├-value: int literal 1 (int)
      #|        |      └-stmt: expr statement
      #|        |              └-assignment expr: = (int)
      #|        |                ├-lvalue: variable x (int)
      #|        |                └-rvalue: int literal 1 (int)
      #|        ├-[3]: break statement
      #|        ├-[4]: case statement
      #|        |      ├-value: int literal 2 (int)
      #|        |      └-stmt: expr statement
      #|        |              └-assignment expr: = (int)
      #|        |                ├-lvalue: variable x (int)
      #|        |                └-rvalue: int literal 2 (int)
      #|        └-[5]: break statement
    ),
  )
  assert_true(_rest is [{ kind: EOF, .. }])
}

///|
test "Switch Statement Parse Error Test" {
  // Error test: missing '(' after 'switch'
  let code_err1 = "switch x) {}"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("x", CType::int())
  let r = try? ctx_err1.parse_switch_statement(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: missing ')' after expression
  let code_err2 = "switch (x {}"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("x", CType::int())
  let r = try? ctx_err2.parse_switch_statement(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: invalid expression
  let code_err3 = "switch (?) {}"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_switch_statement(ctx_err3.tokens)
  assert_true(r is Err(_))
}
