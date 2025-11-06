///|
///
/// Multiplicative Expression
///
/// Multiplicative expressions are binary expressions that perform
/// multiplication, division, or modulo operations on cast expressions.
///
/// ## Examples
///
/// ```c
/// a * b;       // Multiplication
/// x / y;       // Division
/// n % m;       // Modulo
/// a * b / c;   // Multiple operations (left-associative)
/// 10 * 2;      // With literals
/// ```
///
/// ## Grammar (EBNF)
///
/// multiplicative_expression
///   : cast_expression
///   | multiplicative_expression '*' cast_expression
///   | multiplicative_expression '/' cast_expression
///   | multiplicative_expression '%' cast_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_multi_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (MultiExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct MultiExpr {
  kind : MultiExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for MultiExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for MultiExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn MultiExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    CastExpr(cast_expr) => cast_expr.to_string(color~)
    MulExpr(left, right) | DivExpr(left, right) | ModExpr(left, right) => {
      let op = match self.kind {
        MulExpr(_, _) => "*"
        DivExpr(_, _) => "/"
        ModExpr(_, _) => "%"
        _ => ""
      }
      let prefix = if color {
        @color.taint("multiplicative expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "multiplicative expr: \{op} " + "(\{self.ctype})"
      }
      let left_str = left.to_string(color~)
      let right_str = right.to_string(color~)
      // Add backtick prefix to each line of nested expressions
      let left_lines = left_str.split("\n")
      let left_formatted = format_lines(left_lines, head_with="├-")
      let right_lines = right_str.split("\n")
      let right_formatted = format_lines(right_lines, head_with="└-")
      "\{prefix}\n\{left_formatted}\n\{right_formatted}"
    }
  }
}

///|
pub enum MultiExprKind {
  CastExpr(CastExpr)
  MulExpr(MultiExpr, CastExpr)
  DivExpr(MultiExpr, CastExpr)
  ModExpr(MultiExpr, CastExpr)
} derive(Eq)

///|
/// Parse a multiplicative expression from the given tokens.
///
/// Returns a tuple containing the parsed MultiExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a * b;       // Multiplication
/// x / y;       // Division
/// n % m;       // Modulo
/// a * b / c;   // Multiple operations (left-associative)
/// 10 * 2;      // With literals
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x * y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (multi_expr, rest) = ctx.parse_multi_expr(ctx.tokens)
/// inspect(
///   multi_expr.to_string(color=false),
///   content=(
///     #|multiplicative expr: * (int)
///     #|├-variable x (int)
///     #|└-variable y (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse cast expression fails.
///
///    e.g.,
///
///    ```c
///    * 10  // invalid cast expression before '*'
///    ```
///
/// 2. The operand type is not compatible with the multiplicative operator.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    p1 * p2;  // Invalid use of '*' operator on struct types
///    ```
pub fn Context::parse_multi_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (MultiExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_cast_expr, rest) = self.parse_cast_expr(tokens)
  let mut multi_expr = MultiExpr::{
    kind: CastExpr(first_cast_expr),
    ctype: first_cast_expr.cast_to,
    tokens: first_cast_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("*"), .. } as op_tok, .. rest] => {
      let (right_cast_expr, rest) = self.parse_cast_expr(rest)
      let ctype = match multi_expr.ctype.common_type(right_cast_expr.cast_to) {
        Some(common) => common
        None => {
          let msg = "Invalid operands to '*': '\{multi_expr.ctype}' and '\{right_cast_expr.cast_to}'"
          raise ParseError(op_tok, msg)
        }
      }
      multi_expr = MultiExpr::{
        kind: MulExpr(multi_expr, right_cast_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("/"), .. } as op_tok, .. rest] => {
      let (right_cast_expr, rest) = self.parse_cast_expr(rest)
      let ctype = match multi_expr.ctype.common_type(right_cast_expr.cast_to) {
        Some(common) => common
        None => {
          let msg = "Invalid operands to '/': '\{multi_expr.ctype}' and '\{right_cast_expr.cast_to}'"
          raise ParseError(op_tok, msg)
        }
      }
      multi_expr = MultiExpr::{
        kind: DivExpr(multi_expr, right_cast_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("%"), .. } as op_tok, .. rest] => {
      let (right_cast_expr, rest) = self.parse_cast_expr(rest)
      if !multi_expr.ctype.is_integral() {
        let msg = "Invalid operands to '%': left operand '\{multi_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      if !right_cast_expr.cast_to.is_integral() {
        let msg = "Invalid operands to '%': right operand '\{right_cast_expr.cast_to}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      let ctype = match multi_expr.ctype.common_type(right_cast_expr.cast_to) {
        Some(common) => common
        None => {
          let msg = "Invalid operands to '%': '\{multi_expr.ctype}' and '\{right_cast_expr.cast_to}'"
          raise ParseError(op_tok, msg)
        }
      }
      multi_expr = MultiExpr::{
        kind: ModExpr(multi_expr, right_cast_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (multi_expr, rest)
}

///|
pub fn MultiExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    CastExpr(cast_expr) => cast_expr.is_constant()
    MulExpr(left, right) => left.is_constant() && right.is_constant()
    DivExpr(left, right) => left.is_constant() && right.is_constant()
    ModExpr(left, right) => left.is_constant() && right.is_constant()
  }
}

///|
pub fn MultiExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    CastExpr(cast_expr) => cast_expr.eval_as_int()
    MulExpr(left, right) => left.eval_as_int() * right.eval_as_int()
    DivExpr(left, right) => {
      let divisor = right.eval_as_int()
      if divisor == 0 {
        let msg = "Division by zero in multiplicative expression"
        raise ParseError(right.tokens[0], msg)
      }
      left.eval_as_int() / divisor
    }
    ModExpr(left, right) => {
      let divisor = right.eval_as_int()
      if divisor == 0 {
        let msg = "Modulo by zero in multiplicative expression"
        raise ParseError(right.tokens[0], msg)
      }
      left.eval_as_int() % divisor
    }
  }
}

///|
test "Multiplicative Expr Parse Test" {
  let color = false
  let code =
    #|x ; x * y ; a / b ; m % n ; x * y / z ; a * b % c ; 
    #|10 * 2 ; 3.14 / 2.0 ; i * j * k ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  let ctype_int = CType::int()
  ctx
  ..add_var("x", ctype_int)
  ..add_var("y", ctype_int)
  ..add_var("a", ctype_int)
  ..add_var("b", ctype_int)
  ..add_var("m", ctype_int)
  ..add_var("n", ctype_int)
  ..add_var("z", ctype_int)
  ..add_var("c", ctype_int)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("k", ctype_int)

  // Parse `x` (no multiplicative operation)
  let (multi_expr, rest) = ctx.parse_multi_expr(ctx.tokens)
  inspect(multi_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `x * y`
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: * (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `a / b`
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: / (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `m % n`
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: % (int)
      #|├-variable m (int)
      #|└-variable n (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `x * y / z` (left-associative)
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: / (int)
      #|├-multiplicative expr: * (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `a * b % c` (left-associative)
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: % (int)
      #|├-multiplicative expr: * (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `10 * 2` (with literals)
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: * (int)
      #|├-int literal 10 (int)
      #|└-int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `3.14 / 2.0` (with float literals)
  let rest = next_check_point(rest)
  let (multi_expr, rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: / (double)
      #|├-double literal 3.14 (double)
      #|└-double literal 2 (double)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )

  // Parse `i * j * k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (multi_expr, _rest) = ctx.parse_multi_expr(rest)
  inspect(
    multi_expr.to_string(color~),
    content=(
      #|multiplicative expr: * (int)
      #|├-multiplicative expr: * (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_multi_expr(multi_expr.tokens) is (re_multi_expr, re_rest) &&
    re_multi_expr == multi_expr &&
    re_rest is [],
  )
}

///|
test "Multiplicative Expr Error Test" {
  // Error test: struct * struct (incompatible types)
  let code_err1 = "p1 * p2"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1.add_var("p1", point_struct)
  ctx_err1.add_var("p2", point_struct)
  let r = try? ctx_err1.parse_multi_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: void * int (incompatible types)
  let code_err2 = "v * x"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("v", CType::void_())
  ctx_err2.add_var("x", CType::int())
  let r = try? ctx_err2.parse_multi_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: float % int (modulo requires integer types)
  let code_err3 = "f % i2"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("f", CType::float())
  ctx_err3.add_var("i2", CType::int())
  let r = try? ctx_err3.parse_multi_expr(ctx_err3.tokens)
  assert_true(r is Err(_))
}

///|
test "Multiplicative Expr Constant Eval Test" {

}
