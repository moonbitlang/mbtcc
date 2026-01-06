///|
///
/// Conditional Expression (Ternary Operator)
///
/// Conditional expressions are ternary expressions that evaluate a condition
/// and return one of two values based on the result. This is also known as
/// the ternary operator.
///
/// ## Examples
///
/// ```c
/// a > b ? a : b;              // Maximum of a and b
/// x == 0 ? 1 : -1;            // Conditional value
/// flag ? x + y : x - y;       // Conditional operation
/// a ? b ? c : d : e;          // Nested conditionals (right-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// conditional_expression
///   : logical_or_expression
///   | logical_or_expression '?' expression ':' conditional_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_conditional_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (ConditionalExpr, ArrayView[Token]) raise ParseError
/// ```
#alias(ConstantExpr)
pub struct ConditionalExpr {
  kind : ConditionalExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ConditionalExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for ConditionalExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn ConditionalExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    LogicalOrExpr(or_expr) => or_expr.to_string(color~)
    ConditionalExpr(cond, then_expr, else_expr) => {
      let prefix = if color {
        @color.taint("conditional expr: ? : ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "conditional expr: ? : " + "(\{self.ctype})"
      }
      let cond_str = cond.to_string(color~)
      let then_str = then_expr.to_string(color~)
      let else_str = else_expr.to_string(color~)
      // Format nested expressions
      let cond_lines = cond_str.split("\n").to_array().iterator()
      let cond_formatted = format_lines(
        cond_lines,
        head_with="├-cond: ",
        continue_with="│       ",
      )
      let then_lines = then_str.split("\n").to_array().iterator()
      let then_formatted = format_lines(
        then_lines,
        head_with="├-then: ",
        continue_with="│       ",
      )
      let else_lines = else_str.split("\n").to_array().iterator()
      let else_formatted = format_lines(
        else_lines,
        head_with="└-else: ",
        continue_with="        ",
      )
      "\{prefix}\n\{cond_formatted}\n\{then_formatted}\n\{else_formatted}"
    }
  }
}

///|
#alias(ConstantExprKind)
pub enum ConditionalExprKind {
  LogicalOrExpr(LogicalOrExpr)
  ConditionalExpr(LogicalOrExpr, Expr, ConditionalExpr)
} derive(Eq)

///|
/// Parse a conditional expression from the given tokens.
///
/// Returns a tuple containing the parsed ConditionalExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a > b ? a : b;              // Maximum of a and b
/// x == 0 ? 1 : -1;            // Conditional value
/// flag ? x + y : x - y;       // Conditional operation
/// a ? b ? c : d : e;          // Nested conditionals (right-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x > 0 ? x : -x"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// let (cond_expr, rest) = ctx.parse_conditional_expr(ctx.tokens)
/// inspect(
///   cond_expr.to_string(color=false),
///   content=(
///     #|conditional expr: ? : (int)
///     #|├-cond: relational expr: > (int)
///     #|│       ├-variable x (int)
///     #|│       └-int literal 0 (int)
///     #|├-then: variable x (int)
///     #|└-else: unary operator - (int)
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
/// 1. Parse logical or expression fails.
///
///    e.g.,
///    ```c
///    ? x : y  // invalid logical or expression before '?'
///    ```
///
/// 2. Missing ':' in conditional expression.
///
///    e.g.,
///    ```c
///    x > 0 ? 1  // missing ':' and else expression
///    ```
///
/// 3. The types of then and else expressions are incompatible.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    int i;
///    x > 0 ? p1 : i;  // Incompatible types
///    ```
pub fn Context::parse_conditional_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ConditionalExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let (logical_or_expr, rest) = self.parse_logical_or_expr(tokens)
  guard rest is [{ kind: Question, .. }, .. rest] else {
    let cond_expr = ConditionalExpr::{
      kind: LogicalOrExpr(logical_or_expr),
      ctype: logical_or_expr.ctype,
      tokens: init_tokens[0:rest.start_offset() - start_offset],
    }
    return (cond_expr, rest)
  }
  let (then_expr, rest) = self.parse_expr(rest)
  guard rest is [{ kind: Colon, .. }, .. rest] else {
    raise ParseError(rest[0], "Expected ':' in conditional expression")
  }
  let (else_expr, rest) = self.parse_conditional_expr(rest)
  let ctype = CType::common_type(then_expr.ctype, else_expr.ctype)
  guard ctype is Some(ctype) else {
    raise ParseError(
      init_tokens[0],
      "Incompatible types in conditional expression",
    )
  }
  let cond_expr = ConditionalExpr::{
    kind: ConditionalExpr(logical_or_expr, then_expr, else_expr),
    ctype,
    tokens: init_tokens[0:rest.start_offset() - start_offset],
  }
  (cond_expr, rest)
}

///|
pub fn Context::parse_constant_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ConstantExpr, ArrayView[Token]) raise ParseError {
  let (cond_expr, rest) = self.parse_conditional_expr(tokens)
  guard cond_expr.is_constant() else {
    raise ParseError(cond_expr.tokens[0], "Expected constant expression")
  }
  (cond_expr, rest)
}

///|
pub fn ConditionalExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    LogicalOrExpr(expr) => expr.is_constant()
    ConditionalExpr(cond, then_expr, else_expr) =>
      cond.is_constant() && then_expr.is_constant() && else_expr.is_constant()
  }
}

///|
pub fn ConditionalExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    LogicalOrExpr(expr) => expr.eval_as_int()
    ConditionalExpr(cond, then_expr, else_expr) => {
      let cond_val = cond.eval_as_int()
      if cond_val != 0 {
        then_expr.eval_as_int()
      } else {
        else_expr.eval_as_int()
      }
    }
  }
}

///|
test "Conditional Expr Parse Test" {
  let color = false
  let code =
    #|x ; x > 0 ? x : -x ; x == 0 ? 1 : -1 ; 
    #|a > b ? a : b ; flag ? x + y : x - y ;
    #|a ? b ? c : d : e ; 1 ? 2 : 3 ? 4 : 5 ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("x", CType::int())
  ..add_var("a", CType::int())
  ..add_var("b", CType::int())
  ..add_var("c", CType::int())
  ..add_var("d", CType::int())
  ..add_var("e", CType::int())
  ..add_var("y", CType::int())
  ..add_var("flag", CType::int())

  // Parse `x` (no conditional operation)
  let (cond_expr, rest) = ctx.parse_conditional_expr(ctx.tokens)
  inspect(cond_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )

  // Parse `x > 0 ? x : -x`
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(
    cond_expr.to_string(color~),
    content=(
      #|conditional expr: ? : (int)
      #|├-cond: relational expr: > (int)
      #|│       ├-variable x (int)
      #|│       └-int literal 0 (int)
      #|├-then: variable x (int)
      #|└-else: unary operator - (int)
      #|        └-variable x (int)
    ),
  )
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )

  // Parse `x == 0 ? 1 : -1`
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(
    cond_expr.to_string(color~),
    content=(
      #|conditional expr: ? : (int)
      #|├-cond: equality expr: == (int)
      #|│       ├-variable x (int)
      #|│       └-int literal 0 (int)
      #|├-then: int literal 1 (int)
      #|└-else: unary operator - (int)
      #|        └-int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )

  // Parse `a > b ? a : b`
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(
    cond_expr.to_string(color~),
    content=(
      #|conditional expr: ? : (int)
      #|├-cond: relational expr: > (int)
      #|│       ├-variable a (int)
      #|│       └-variable b (int)
      #|├-then: variable a (int)
      #|└-else: variable b (int)
    ),
  )
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )

  // Parse `flag ? x + y : x - y`
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(
    cond_expr.to_string(color~),
    content=(
      #|conditional expr: ? : (int)
      #|├-cond: variable flag (int)
      #|├-then: additive expr: + (int)
      #|│       ├-variable x (int)
      #|│       └-variable y (int)
      #|└-else: additive expr: - (int)
      #|        ├-variable x (int)
      #|        └-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )

  // Parse `a ? b ? c : d : e` (nested, right-associative)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(
    cond_expr.to_string(color~),
    content=(
      #|conditional expr: ? : (int)
      #|├-cond: variable a (int)
      #|├-then: conditional expr: ? : (int)
      #|│       ├-cond: variable b (int)
      #|│       ├-then: variable c (int)
      #|│       └-else: variable d (int)
      #|└-else: variable e (int)
    ),
  )
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )

  // Parse `1 ? 2 : 3 ? 4 : 5` (right-associative: 1 ? 2 : (3 ? 4 : 5))
  let rest = next_check_point(rest)
  let (cond_expr, _rest) = ctx.parse_conditional_expr(rest)
  inspect(
    cond_expr.to_string(color~),
    content=(
      #|conditional expr: ? : (int)
      #|├-cond: int literal 1 (int)
      #|├-then: int literal 2 (int)
      #|└-else: conditional expr: ? : (int)
      #|        ├-cond: int literal 3 (int)
      #|        ├-then: int literal 4 (int)
      #|        └-else: int literal 5 (int)
    ),
  )
  assert_true(
    ctx.parse_conditional_expr(cond_expr.tokens) is (re_cond_expr, re_rest) &&
    re_cond_expr == cond_expr &&
    re_rest is [],
  )
}

///|
test "Conditional Expr Parse Error Test" {
  // Error test: incompatible types in conditional
  let code_err1 = "x > 0 ? p : i"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1
  ..add_var("x", CType::int())
  ..add_var("p", point_struct)
  ..add_var("i", CType::int())
  let r = try? ctx_err1.parse_conditional_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: missing colon
  let code_err2 = "x > 0 ? 1"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("x", CType::int())
  let r = try? ctx_err2.parse_conditional_expr(ctx_err2.tokens)
  assert_true(r is Err(_))
}

///|
test "Conditional Expr Constant Eval Test" {
  // Test eval_as_int for conditional expressions
  let code =
    #|42 ; 1 ? 10 : 20 ; 0 ? 10 : 20 ; 
    #|5 > 3 ? 100 : 200 ; 2 < 1 ? 50 : 60 ;
    #|1 ? 2 ? 3 : 4 : 5 ; 0 ? 1 : 1 ? 2 : 3 ;
    #|x ; x > 0 ? x : -x ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())

  // Parse and eval `42` (just a logical or expr)
  let (cond_expr, rest) = ctx.parse_conditional_expr(ctx.tokens)
  inspect(cond_expr.eval_as_int(), content="42")
  assert_true(cond_expr.is_constant())

  // Parse and eval `1 ? 10 : 20` (true condition)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(cond_expr.eval_as_int(), content="10")
  assert_true(cond_expr.is_constant())

  // Parse and eval `0 ? 10 : 20` (false condition)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(cond_expr.eval_as_int(), content="20")
  assert_true(cond_expr.is_constant())

  // Parse and eval `5 > 3 ? 100 : 200` (true condition with comparison)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(cond_expr.eval_as_int(), content="100")
  assert_true(cond_expr.is_constant())

  // Parse and eval `2 < 1 ? 50 : 60` (false condition with comparison)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(cond_expr.eval_as_int(), content="60")
  assert_true(cond_expr.is_constant())

  // Parse and eval `1 ? 2 ? 3 : 4 : 5` (nested, evaluates to 3)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(cond_expr.eval_as_int(), content="3")
  assert_true(cond_expr.is_constant())

  // Parse and eval `0 ? 1 : 1 ? 2 : 3` (nested, evaluates to 2)
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  inspect(cond_expr.eval_as_int(), content="2")
  assert_true(cond_expr.is_constant())

  // Error test: variable is not constant
  let rest = next_check_point(rest)
  let (cond_expr, rest) = ctx.parse_conditional_expr(rest)
  assert_false(cond_expr.is_constant())
  let r = try? cond_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: conditional with variable is not constant
  let rest = next_check_point(rest)
  let (cond_expr, _rest) = ctx.parse_conditional_expr(rest)
  assert_false(cond_expr.is_constant())
  let r = try? cond_expr.eval_as_int()
  assert_true(r is Err(_))
}
