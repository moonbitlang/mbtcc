///|
///
/// Additive Expression
///
/// Additive expressions are binary expressions that perform
/// addition or subtraction operations on multiplicative expressions.
///
/// ## Examples
///
/// ```c
/// a + b;       // Addition
/// x - y;       // Subtraction
/// a + b - c;   // Multiple operations (left-associative)
/// 10 + 20;     // With literals
/// ```
///
/// ## Grammar (EBNF)
///
/// additive_expression
///   : multiplicative_expression
///   | additive_expression '+' multiplicative_expression
///   | additive_expression '-' multiplicative_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_addi_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (AddiExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct AddiExpr {
  kind : AddiExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AddiExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for AddiExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// additive expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn AddiExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  match self.kind {
    MultiExpr(multi_expr) => multi_expr.to_string(color~, indent~)
    AddExpr(left, right) | SubExpr(left, right) => {
      let op = match self.kind {
        AddExpr(_, _) => "+"
        SubExpr(_, _) => "-"
        _ => ""
      }
      let prefix = if color {
        @color.taint("additive expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "additive expr: \{op} " + "(\{self.ctype})"
      }
      let left_str = left.to_string(color~, indent~)
      let right_str = right.to_string(color~, indent~)
      // Add backtick prefix to each line of nested expressions
      let left_lines = left_str.split("\n")
      let left_formatted = left_lines.map(fn(line) { "`\{line}" }).join("\n")
      let right_lines = right_str.split("\n")
      let right_formatted = right_lines.map(fn(line) { "`\{line}" }).join("\n")
      let s = "\{prefix}\n\{left_formatted}\n\{right_formatted}"
      " ".repeat(indent) + s
    }
  }
}

///|
pub enum AddiExprKind {
  MultiExpr(MultiExpr)
  AddExpr(AddiExpr, MultiExpr)
  SubExpr(AddiExpr, MultiExpr)
} derive(Eq)

///|
/// Parse an additive expression from the given tokens.
///
/// Returns a tuple containing the parsed AddiExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a + b;       // Addition
/// x - y;       // Subtraction
/// a + b - c;   // Multiple operations (left-associative)
/// 10 + 20;     // With literals
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x + y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (addi_expr, rest) = ctx.parse_addi_expr(ctx.tokens)
/// inspect(
///   addi_expr.to_string(color=false),
///   content=(
///     
///   #|additive expr: + (int)
/// #|`variable x (int)
/// #|`variable y (int)
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
/// 1. Parse multiplicative expression fails.
///
///    e.g.,
///
///    ```c
///    + 10  // invalid multiplicative expression before '+'
///    ```
///
/// 2. The operand type is not compatible with the additive operator.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    p1 + p2;  // Invalid use of '+' operator on struct types
///    ```
pub fn Context::parse_addi_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (AddiExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_multi_expr, rest) = self.parse_multi_expr(tokens)
  let mut addi_expr = AddiExpr::{
    kind: MultiExpr(first_multi_expr),
    ctype: first_multi_expr.ctype,
    tokens: first_multi_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("+"), .. }, .. rest] => {
      let (right_multi_expr, rest) = self.parse_multi_expr(rest)
      // TODO: Type checking for addition operator
      let ctype = addi_expr.ctype
      addi_expr = AddiExpr::{
        kind: AddExpr(addi_expr, right_multi_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("-"), .. }, .. rest] => {
      let (right_multi_expr, rest) = self.parse_multi_expr(rest)
      // TODO: Type checking for subtraction operator
      let ctype = addi_expr.ctype
      addi_expr = AddiExpr::{
        kind: SubExpr(addi_expr, right_multi_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (addi_expr, rest)
}

///|
pub struct ShiftExpr {
  kind : ShiftExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ShiftExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for ShiftExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn ShiftExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  ...
}

///|
pub enum ShiftExprKind {
  AddiExpr(AddiExpr)
  ShlExpr(ShiftExpr, AddiExpr)
  ShrExpr(ShiftExpr, AddiExpr)
} derive(Eq)

///|
///
/// AI DO
pub fn Context::parse_shift_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ShiftExpr, ArrayView[Token]) raise ParseError {
  ...
}

///|
pub struct RelationalExpr {
  kind : RelationalExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for RelationalExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for RelationalExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// relational expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn RelationalExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  ...
}

///|
pub enum RelationalExprKind {
  ShiftExpr(ShiftExpr)
  LTExpr(RelationalExpr, ShiftExpr)
  GTExpr(RelationalExpr, ShiftExpr)
  LEExpr(RelationalExpr, ShiftExpr)
  GEExpr(RelationalExpr, ShiftExpr)
} derive(Eq)

///|
pub struct EqualityExpr {
  kind : EqualityExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for EqualityExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for EqualityExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// equality expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn EqualityExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  ...
}

///|
pub enum EqualityExprKind {
  RelationalExpr(RelationalExpr)
  EQExpr(EqualityExpr, RelationalExpr)
  NEExpr(EqualityExpr, RelationalExpr)
} derive(Eq)

///|
///
/// AI DO
pub fn Context::parse_equality_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (EqualityExpr, ArrayView[Token]) raise ParseError {
  ...
}

///|
pub struct AndExpr {
  left : EqualityExpr
  right : EqualityExpr
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub struct ExclusiveOrExpr {
  left : AndExpr
  right : AndExpr
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub struct InclusiveOrExpr {
  left : ExclusiveOrExpr
  right : ExclusiveOrExpr
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub struct LogicalAndExpr {
  left : InclusiveOrExpr
  right : InclusiveOrExpr
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub struct LogicalOrExpr {
  left : LogicalAndExpr
  right : LogicalAndExpr
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub struct ConditionalExpr {
  cond : LogicalOrExpr
  then_expr : LogicalOrExpr
  else_expr : LogicalOrExpr
  ctype : CType
  tokens : ArrayView[Token]
}

// Convert From ConditionalExpr, but check all
// operands are constant expressions

///|
pub struct ConstantExpr {
  cond : LogicalOrExpr
  then_expr : LogicalOrExpr
  else_expr : LogicalOrExpr
  tokens : ArrayView[Token]
}

///|
pub struct AssignExpr {
  kind : AssignExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub enum AssignExprKind {
  Conditional(ConditionalExpr)
  Assign(UnaryExpr, AssignExpr)
  MulAssign(UnaryExpr, AssignExpr)
  DivAssign(UnaryExpr, AssignExpr)
  ModAssign(UnaryExpr, AssignExpr)
  AddAssign(UnaryExpr, AssignExpr)
  SubAssign(UnaryExpr, AssignExpr)
  ShlAssign(UnaryExpr, AssignExpr)
  ShrAssign(UnaryExpr, AssignExpr)
  AndAssign(UnaryExpr, AssignExpr)
  XorAssign(UnaryExpr, AssignExpr)
  OrAssign(UnaryExpr, AssignExpr)
}

///|
pub struct Expr {
  assign_exprs : Array[AssignExpr]
  tokens : ArrayView[Token]
}

///|
test "Additive Expr Parse Test" {
  let color = false
  let code =
    #|x ; x + y ; a - b ; x + y - z ; a - b + c ; 
    #|10 + 20 ; 3.14 - 2.0 ; i + j + k ; x * y + z ; a + b * c ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  let ctype_int = CType::int()
  ctx
  ..add_var("x", ctype_int)
  ..add_var("y", ctype_int)
  ..add_var("a", ctype_int)
  ..add_var("b", ctype_int)
  ..add_var("z", ctype_int)
  ..add_var("c", ctype_int)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("k", ctype_int)

  // Parse `x` (no additive operation)
  let (addi_expr, rest) = ctx.parse_addi_expr(ctx.tokens)
  inspect(addi_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `x + y`
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|`variable x (int)
      #|`variable y (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `a - b`
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: - (int)
      #|`variable a (int)
      #|`variable b (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `x + y - z` (left-associative)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: - (int)
      #|`additive expr: + (int)
      #|``variable x (int)
      #|``variable y (int)
      #|`variable z (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `a - b + c` (left-associative)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|`additive expr: - (int)
      #|``variable a (int)
      #|``variable b (int)
      #|`variable c (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `10 + 20` (with literals)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|`int literal 10 (int)
      #|`int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `3.14 - 2.0` (with float literals)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: - (double)
      #|`double literal 3.14 (double)
      #|`double literal 2 (double)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `i + j + k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|`additive expr: + (int)
      #|``variable i (int)
      #|``variable j (int)
      #|`variable k (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `x * y + z` (multiplicative has higher precedence)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|`multiplicative expr: * (int)
      #|``variable x (int)
      #|``variable y (int)
      #|`variable z (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `a + b * c` (multiplicative has higher precedence)
  let rest = next_check_point(rest)
  let (addi_expr, _rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|`variable a (int)
      #|`multiplicative expr: * (int)
      #|``variable b (int)
      #|``variable c (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )
}

///|
test "Shift Expr Parse Test" {

}

///|
test "Relational Expr Parse Test" {

}

///|
test "Equality Expr Parse Test" {

}

///|
test "And Expr Parse Test" {

}

///|
test "Exclusive Or Expr Parse Test" {

}

///|
test "Inclusive Or Expr Parse Test" {

}

///|
test "Logical And Expr Parse Test" {

}

///|
test "Logical Or Expr Parse Test" {

}

///|
test "Conditional Expr Parse Test" {

}

///|
test "Assign Expr Parse Test" {

}
