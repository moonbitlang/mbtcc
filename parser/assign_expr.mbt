///|
///
/// Assignment Expression
///
/// Assignment expressions are expressions that assign values to lvalues.
/// They support various compound assignment operators like =, +=, -=, etc.
///
/// ## Examples
///
/// ```c
/// x = 10;              // Simple assignment
/// y += 5;              // Compound addition assignment
/// z *= 2;              // Compound multiplication assignment
/// a = b = c;           // Chained assignment (right-associative)
/// *p = 100;            // Pointer assignment
/// arr[i] = value;      // Array element assignment
/// x >>= 2;             // Right shift assignment
/// ```
///
/// ## Grammar (EBNF)
///
/// assignment_expression
///   : conditional_expression
///   | unary_expression assignment_operator assignment_expression
///   ;
///
/// assignment_operator
///   : '=' | '*=' | '/=' | '%=' | '+=' | '-='
///   | '<<=' | '>>=' | '&=' | '^=' | '|='
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_assign_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (AssignExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct AssignExpr {
  kind : AssignExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AssignExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for AssignExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn AssignExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    Conditional(cond_expr) => cond_expr.to_string(color~)
    Assign(unary_expr, assign_op, assign_expr) => {
      let op_str = match assign_op {
        Assign => "="
        MulAssign => "*="
        DivAssign => "/="
        ModAssign => "%="
        AddAssign => "+="
        SubAssign => "-="
        ShlAssign => "<<="
        ShrAssign => ">>="
        AndAssign => "&="
        XorAssign => "^="
        OrAssign => "|="
      }
      let prefix = if color {
        @color.taint("assignment expr: \{op_str} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "assignment expr: \{op_str} " + "(\{self.ctype})"
      }
      let left_str = unary_expr.to_string(color~)
      let right_str = assign_expr.to_string(color~)
      // Format nested expressions
      let left_lines = left_str.split("\n").to_array().iterator()
      let left_formatted = format_lines(
        left_lines,
        head_with="├-lvalue: ",
        continue_with="│         ",
      )
      let right_lines = right_str.split("\n").to_array().iterator()
      let right_formatted = format_lines(
        right_lines,
        head_with="└-rvalue: ",
        continue_with="          ",
      )
      "\{prefix}\n\{left_formatted}\n\{right_formatted}"
    }
  }
}

///|
pub enum AssignExprKind {
  Conditional(ConditionalExpr)
  Assign(UnaryExpr, AssignOp, AssignExpr)
} derive(Eq)

///|
/// Parse an assignment expression from the given tokens.
///
/// Returns a tuple containing the parsed AssignExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// x = 10;              // Simple assignment
/// y += 5;              // Compound addition assignment
/// z *= 2;              // Compound multiplication assignment
/// a = b = c;           // Chained assignment (right-associative)
/// *p = 100;            // Pointer assignment
/// arr[i] = value;      // Array element assignment
/// x >>= 2;             // Right shift assignment
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x = 10"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// let (assign_expr, rest) = ctx.parse_assign_expr(ctx.tokens)
/// inspect(
///   assign_expr.to_string(color=false),
///   content=(
///     #|assignment expr: = (int)
///     #|├-lvalue: variable x (int)
///     #|└-rvalue: int literal 10 (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse conditional expression fails.
///
///    e.g.,
///    ```c
///    = 10  // invalid conditional expression before '='
///    ```
///
/// 2. Left-hand side of assignment is not a modifiable lvalue.
///
///    e.g.,
///    ```c
///    10 = x;         // literal is not an lvalue
///    x + y = 10;     // expression is not an lvalue
///    const int c = 5;
///    c = 10;         // const variable is not modifiable
///    ```
///
/// 3. Invalid assignment operator.
///
///    e.g.,
///    ```c
///    x := 10;  // ':=' is not a valid assignment operator in C
///    ```
pub fn Context::parse_assign_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AssignExpr, ArrayView[Token]) raise ParseError {
  let (conditional_expr, rest) = self.parse_conditional_expr(tokens)
  guard rest is [{ kind: AssignOp(assign_op), .. } as tok, .. rest] else {
    let assign_expr = AssignExpr::{
      kind: Conditional(conditional_expr),
      ctype: conditional_expr.ctype,
      tokens: conditional_expr.tokens,
    }
    return (assign_expr, rest)
  }
  guard conditional_expr.kind is LogicalOrExpr(e) &&
    e.kind is LogicalAndExpr(e) &&
    e.kind is InclusiveOrExpr(e) &&
    e.kind is ExclusiveOrExpr(e) &&
    e.kind is AndExpr(e) &&
    e.kind is EqualityExpr(e) &&
    e.kind is RelationalExpr(e) &&
    e.kind is ShiftExpr(e) &&
    e.kind is AddiExpr(e) &&
    e.kind is MultiExpr(e) &&
    e.kind is CastExpr(e) &&
    e.kind is UnaryExpr(unary_expr) else {
    raise ParseError(
      rest[0],
      "Left-hand side of assignment must be a modifiable lvalue",
    )
  }
  guard unary_expr.is_assignable() else {
    raise ParseError(
      tok, "Left-hand side of assignment must be a modifiable lvalue",
    )
  }
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let assign_op = match assign_op {
    "=" => AssignOp::Assign
    "*=" => MulAssign
    "/=" => DivAssign
    "%=" => ModAssign
    "+=" => AddAssign
    "-=" => SubAssign
    "<<=" => ShlAssign
    ">>=" => ShrAssign
    "&=" => AndAssign
    "^=" => XorAssign
    "|=" => OrAssign
    _ => raise ParseError(rest[0], "Invalid assignment operator")
  }
  let (assign_expr, rest) = self.parse_assign_expr(rest)
  let assign_expr = AssignExpr::{
    kind: Assign(unary_expr, assign_op, assign_expr),
    ctype: assign_expr.ctype, // TODO: once the left type != right type, what type it becomes?
    tokens: tokens[0:rest.start_offset() - start_offset],
  }
  (assign_expr, rest)
}

///|
pub(all) enum AssignOp {
  Assign // =
  MulAssign // *=
  DivAssign // /=
  ModAssign // %=
  AddAssign // +=
  SubAssign // -=
  ShlAssign // <<=
  ShrAssign // >>=
  AndAssign // &=
  XorAssign // ^=
  OrAssign // |=
} derive(Eq)

///|
pub fn AssignExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    Conditional(expr) => expr.is_constant()
    _ => false
  }
}

///|
pub fn AssignExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    Conditional(expr) => expr.eval_as_int()
    _ =>
      raise ParseError(
        self.tokens[0],
        "Cannot evaluate non-constant expression as integer",
      )
  }
}

///|
test "Assign Expr Parse Test" {
  let color = false
  let code =
    #|x ; x = 10 ; y += 5 ; z *= 2 ; 
    #|a = b = c ; i -= 1 ; j /= 2 ; k %= 3 ;
    #|m <<= 1 ; n >>= 2 ; p &= 0xFF ; q ^= 1 ; r |= 2 ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("x", CType::int())
  ..add_var("y", CType::int())
  ..add_var("z", CType::int())
  ..add_var("a", CType::int())
  ..add_var("b", CType::int())
  ..add_var("c", CType::int())
  ..add_var("i", CType::int())
  ..add_var("j", CType::int())
  ..add_var("k", CType::int())
  ..add_var("m", CType::int())
  ..add_var("n", CType::int())
  ..add_var("p", CType::int())
  ..add_var("q", CType::int())
  ..add_var("r", CType::int())

  // Parse `x` (no assignment)
  let (assign_expr, rest) = ctx.parse_assign_expr(ctx.tokens)
  inspect(assign_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `x = 10`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: = (int)
      #|├-lvalue: variable x (int)
      #|└-rvalue: int literal 10 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `y += 5`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: += (int)
      #|├-lvalue: variable y (int)
      #|└-rvalue: int literal 5 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `z *= 2`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: *= (int)
      #|├-lvalue: variable z (int)
      #|└-rvalue: int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `a = b = c` (right-associative)
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: = (int)
      #|├-lvalue: variable a (int)
      #|└-rvalue: assignment expr: = (int)
      #|          ├-lvalue: variable b (int)
      #|          └-rvalue: variable c (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `i -= 1`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: -= (int)
      #|├-lvalue: variable i (int)
      #|└-rvalue: int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `j /= 2`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: /= (int)
      #|├-lvalue: variable j (int)
      #|└-rvalue: int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `k %= 3`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: %= (int)
      #|├-lvalue: variable k (int)
      #|└-rvalue: int literal 3 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `m <<= 1`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: <<= (int)
      #|├-lvalue: variable m (int)
      #|└-rvalue: int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `n >>= 2`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: >>= (int)
      #|├-lvalue: variable n (int)
      #|└-rvalue: int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `p &= 0xFF`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: &= (int)
      #|├-lvalue: variable p (int)
      #|└-rvalue: int literal 255 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `q ^= 1`
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: ^= (int)
      #|├-lvalue: variable q (int)
      #|└-rvalue: int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )

  // Parse `r |= 2`
  let rest = next_check_point(rest)
  let (assign_expr, _rest) = ctx.parse_assign_expr(rest)
  inspect(
    assign_expr.to_string(color~),
    content=(
      #|assignment expr: |= (int)
      #|├-lvalue: variable r (int)
      #|└-rvalue: int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_assign_expr(assign_expr.tokens) is (re_assign_expr, re_rest) &&
    re_assign_expr == assign_expr &&
    re_rest is [],
  )
}

///|
test "Assign Expr Parse Error Test" {
  // Error test: assigning to literal (not an lvalue)
  let code_err1 = "10 = x"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("x", CType::int())
  let r = try? ctx_err1.parse_assign_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: assigning to expression (not an lvalue)
  let code_err2 = "x + y = 10"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2..add_var("x", CType::int())..add_var("y", CType::int())
  let r = try? ctx_err2.parse_assign_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: assigning to const variable
  let code_err3 = "c = 10"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("c", CType::const_with(Int))
  let r = try? ctx_err3.parse_assign_expr(ctx_err3.tokens)
  assert_true(r is Err(_))
}

///|
test "Assign Expr Eval Test" {
  // Test eval_as_int for assignment expressions
  let code =
    #|42 ; 1 ? 10 : 20 ; x > 0 ? x : -x ;
    #|x = 10 ; y += 5 ; a = b = c ;
  let ctx = Context::new(code~, source_file="demo")
  ctx
  ..add_var("x", CType::int())
  ..add_var("y", CType::int())
  ..add_var("a", CType::int())
  ..add_var("b", CType::int())
  ..add_var("c", CType::int())

  // Parse and eval `42` (just a conditional expr wrapped in AssignExpr)
  let (assign_expr, rest) = ctx.parse_assign_expr(ctx.tokens)
  inspect(assign_expr.eval_as_int(), content="42")
  assert_true(assign_expr.is_constant())

  // Parse and eval `1 ? 10 : 20` (conditional expr wrapped in AssignExpr)
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  inspect(assign_expr.eval_as_int(), content="10")
  assert_true(assign_expr.is_constant())

  // Error test: conditional with variable is not constant
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  assert_false(assign_expr.is_constant())
  let r = try? assign_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: assignment is not constant
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  assert_false(assign_expr.is_constant())
  let r = try? assign_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: compound assignment is not constant
  let rest = next_check_point(rest)
  let (assign_expr, rest) = ctx.parse_assign_expr(rest)
  assert_false(assign_expr.is_constant())
  let r = try? assign_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: chained assignment is not constant
  let rest = next_check_point(rest)
  let (assign_expr, _rest) = ctx.parse_assign_expr(rest)
  assert_false(assign_expr.is_constant())
  let r = try? assign_expr.eval_as_int()
  assert_true(r is Err(_))
}
