///|
///
/// Expression (Comma Expression)
///
/// Expressions are sequences of assignment expressions separated by commas.
/// The comma operator evaluates each expression from left to right and
/// returns the value of the rightmost expression.
///
/// ## Examples
///
/// ```c
/// x = 10;              // Single assignment expression
/// i++, j++;            // Multiple expressions with comma operator
/// x = (a++, b++);      // Comma expression in parentheses
/// for (i = 0, j = 0; i < 10; i++, j++)  // In for loop
/// ```
///
/// ## Grammar (EBNF)
///
/// expression
///   : assignment_expression
///   | expression ',' assignment_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (Expr, ArrayView[Token]) raise ParseError
/// ```
pub struct Expr {
  assign_exprs : Array[AssignExpr]
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Expr with equal(self, other) {
  self.assign_exprs == other.assign_exprs
}

///|
pub impl Show for Expr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn Expr::to_string(self : Self, color? : Bool = true) -> String {
  if self.assign_exprs.length() == 1 {
    return self.assign_exprs[0].to_string(color~)
  }
  let prefix = if color {
    @color.taint("comma expr: , ", Magenta) +
    @color.taint("(\{self.ctype})", Green)
  } else {
    "comma expr: , " + "(\{self.ctype})"
  }
  let mut result = prefix
  for i, assign_expr in self.assign_exprs {
    let assign_str = assign_expr.to_string(color~)
    let lines = assign_str.split("\n")
    let is_last = i == self.assign_exprs.length() - 1
    let formatted = if is_last {
      format_lines(lines, head_with="└-[\{i}]: ", continue_with="      ")
    } else {
      format_lines(lines, head_with="├-[\{i}]: ", continue_with="│     ")
    }
    result = result + "\n" + formatted
  }
  result
}

///|
/// Parse an expression from the given tokens.
///
/// Returns a tuple containing the parsed Expr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// x = 10;              // Single assignment expression
/// i++, j++;            // Multiple expressions with comma operator
/// x = (a++, b++);      // Comma expression in parentheses
/// for (i = 0, j = 0; i < 10; i++, j++)  // In for loop
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "i++, j++"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("i", CType::int())
/// ctx.add_var("j", CType::int())
/// let (expr, rest) = ctx.parse_expr(ctx.tokens)
/// inspect(
///   expr.to_string(color=false),
///   content=(
///     #|comma expr: , (int)
///     #|├-[0]: unary operator ++ (int)
///     #|│     └-variable i (int)
///     #|└-[1]: unary operator ++ (int)
///     #|      └-variable j (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse assignment expression fails.
///
///    e.g.,
///    ```c
///    , i++  // invalid assignment expression before ','
///    ```
pub fn Context::parse_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (Expr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let assign_exprs = Array::new()
  let (assign_expr, rest) = self.parse_assign_expr(tokens)
  assign_exprs.push(assign_expr)
  let rest = loop rest {
    [{ kind: Comma, .. }, .. rest] => {
      let (assign_expr, rest) = self.parse_assign_expr(rest)
      assign_exprs.push(assign_expr)
      continue rest
    }
    rest => break rest
  }
  let ctype = assign_exprs.last().unwrap().ctype
  let expr = Expr::{
    assign_exprs,
    ctype,
    tokens: init_tokens[0:rest.start_offset() - start_offset],
  }
  (expr, rest)
}

///|
pub fn Expr::is_constant(self : Self) -> Bool {
  for expr in self.assign_exprs {
    if !expr.is_constant() {
      return false
    }
  }
  true
}

///|
pub fn Expr::eval_as_int(self : Self) -> Int raise ParseError {
  if self.assign_exprs.length() == 0 {
    raise ParseError(
      self.tokens[0],
      "Cannot evaluate empty expression as integer",
    )
  }
  // Evaluate the last assign expression
  self.assign_exprs.last().unwrap().eval_as_int()
}

///|
test "Expr Parse Test" {
  let color = false
  let code =
    #|x ; x = 10 ; i++, j++ ; 
    #|a = 1, b = 2, c = 3 ; x = y, y = z ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("x", CType::int())
  ..add_var("y", CType::int())
  ..add_var("z", CType::int())
  ..add_var("i", CType::int())
  ..add_var("j", CType::int())
  ..add_var("a", CType::int())
  ..add_var("b", CType::int())
  ..add_var("c", CType::int())

  // Parse `x` (single expression)
  let (expr, rest) = ctx.parse_expr(ctx.tokens)
  inspect(expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_expr(expr.tokens) is (re_expr, re_rest) &&
    re_expr == expr &&
    re_rest is [],
  )

  // Parse `x = 10` (single assignment)
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  inspect(
    expr.to_string(color~),
    content=(
      #|assignment expr: = (int)
      #|├-lvalue: variable x (int)
      #|└-rvalue: int literal 10 (int)
    ),
  )
  assert_true(
    ctx.parse_expr(expr.tokens) is (re_expr, re_rest) &&
    re_expr == expr &&
    re_rest is [],
  )

  // Parse `i++, j++` (comma expression)
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  inspect(
    expr.to_string(color~),
    content=(
      #|comma expr: , (int)
      #|├-[0]: unary operator ++ (int)
      #|│     └-variable i (int)
      #|└-[1]: unary operator ++ (int)
      #|      └-variable j (int)
    ),
  )
  assert_true(
    ctx.parse_expr(expr.tokens) is (re_expr, re_rest) &&
    re_expr == expr &&
    re_rest is [],
  )

  // Parse `a = 1, b = 2, c = 3` (multiple comma-separated assignments)
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  inspect(
    expr.to_string(color~),
    content=(
      #|comma expr: , (int)
      #|├-[0]: assignment expr: = (int)
      #|│     ├-lvalue: variable a (int)
      #|│     └-rvalue: int literal 1 (int)
      #|├-[1]: assignment expr: = (int)
      #|│     ├-lvalue: variable b (int)
      #|│     └-rvalue: int literal 2 (int)
      #|└-[2]: assignment expr: = (int)
      #|      ├-lvalue: variable c (int)
      #|      └-rvalue: int literal 3 (int)
    ),
  )
  assert_true(
    ctx.parse_expr(expr.tokens) is (re_expr, re_rest) &&
    re_expr == expr &&
    re_rest is [],
  )

  // Parse `x = y, y = z` (comma expression with assignments)
  let rest = next_check_point(rest)
  let (expr, _rest) = ctx.parse_expr(rest)
  inspect(
    expr.to_string(color~),
    content=(
      #|comma expr: , (int)
      #|├-[0]: assignment expr: = (int)
      #|│     ├-lvalue: variable x (int)
      #|│     └-rvalue: variable y (int)
      #|└-[1]: assignment expr: = (int)
      #|      ├-lvalue: variable y (int)
      #|      └-rvalue: variable z (int)
    ),
  )
  assert_true(
    ctx.parse_expr(expr.tokens) is (re_expr, re_rest) &&
    re_expr == expr &&
    re_rest is [],
  )
}

///|
test "Expr Parse Error Test" {
  // Error test: empty expression
  let code_err1 = ""
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: comma without right-hand side
  let code_err2 = "x,"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("x", CType::int())
  let r = try? ctx_err2.parse_expr(ctx_err2.tokens)
  assert_true(r is Err(_))
}

///|
test "Expr Eval Test" {
  // Test eval_as_int for expressions
  let code =
    #|42 ; 1 ? 10 : 20 ; 
    #|10, 20, 30 ; 1 + 2, 3 * 4 ;
    #|x ; x, y ; x = 10, y = 20 ;
  let ctx = Context::new(code~, source_file="demo")
  ctx..add_var("x", CType::int())..add_var("y", CType::int())

  // Parse and eval `42` (single value wrapped in Expr)
  let (expr, rest) = ctx.parse_expr(ctx.tokens)
  inspect(expr.eval_as_int(), content="42")
  assert_true(expr.is_constant())

  // Parse and eval `1 ? 10 : 20` (conditional wrapped in Expr)
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  inspect(expr.eval_as_int(), content="10")
  assert_true(expr.is_constant())

  // Parse and eval `10, 20, 30` (comma expression evaluates to last value)
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  inspect(expr.eval_as_int(), content="30")
  assert_true(expr.is_constant())

  // Parse and eval `1 + 2, 3 * 4` (comma expression evaluates to 12)
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  inspect(expr.eval_as_int(), content="12")
  assert_true(expr.is_constant())

  // Error test: variable is not constant
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  assert_false(expr.is_constant())
  let r = try? expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: comma expression with variable is not constant
  let rest = next_check_point(rest)
  let (expr, rest) = ctx.parse_expr(rest)
  assert_false(expr.is_constant())
  let r = try? expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: assignment in comma expression is not constant
  let rest = next_check_point(rest)
  let (expr, _rest) = ctx.parse_expr(rest)
  assert_false(expr.is_constant())
  let r = try? expr.eval_as_int()
  assert_true(r is Err(_))
}
