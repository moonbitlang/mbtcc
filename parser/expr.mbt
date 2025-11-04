///|
///
/// Cast Expression
///
/// Cast expressions are expressions that explicitly convert a value from
/// one type to another by specifying a target type in parentheses before
/// the expression, or just wrap a unary expression without casting.
///
/// ## Examples
///
/// ```c
/// (int)3.14;            // Cast double to int
/// (float)x;             // Cast variable x to float
/// (long)(x + y);        // Cast result of expression to long
/// (char *)ptr;          // Cast pointer type
/// (unsigned int)-1;     // Cast signed to unsigned
/// x;                    // Unary expression without cast
/// ```
///
/// ## Grammar (EBNF)
///
/// cast_expression
///   : unary_expression
///   | '(' type_name ')' cast_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_cast_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (CastExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct CastExpr {
  unary_expr : UnaryExpr
  // if no `(typename)` cast
  // set `cst_to` is same as `unary_expr.ctype`
  cast_to : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for CastExpr with equal(self, other) {
  self.unary_expr == other.unary_expr && self.cast_to == other.cast_to
}

///|
pub impl Show for CastExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
/// if cast_to == unary_expr.ctype, just print unary_expr
/// if not, print like:
///
/// cast expr: cast to \{cast_to}
/// `\{unary_expr}
pub fn CastExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  if self.cast_to == self.unary_expr.ctype {
    return self.unary_expr.to_string(color~, indent~)
  }
  let prefix = if color {
    @color.taint("cast expr: cast to \{self.cast_to}", Magenta)
  } else {
    "cast expr: cast to \{self.cast_to}"
  }
  let s = self.unary_expr.to_string(color~, indent~)
  let s = "\{prefix}\n" + "`\{s}"
  " ".repeat(indent) + s
}

///|
/// Parse a cast expression from the given tokens.
///
/// Returns a tuple containing the parsed CastExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// (int)3.14;            // Cast double to int
/// (float)x;             // Cast variable x to float
/// (long)(x + y);        // Cast result of expression to long
/// (char *)ptr;          // Cast pointer type
/// (unsigned int)-1;     // Cast signed to unsigned
/// x;                    // Unary expression without cast
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// let (cast_expr, rest) = ctx.parse_cast_expr(ctx.tokens)
/// inspect(
///   cast_expr.to_string(color=false),
///   content="variable x (int)"
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse unary expression fails.
///
///    e.g.,
///    
///    ```c
///    (int)?  // invalid unary expression after cast
///    ```
///
/// 2. Type name parsing is not yet fully implemented (TODO).
///
///    When encountering `'(' type_name ')' cast_expression`, the parser
///    currently skips the type cast parsing and falls back to parsing
///    as a unary expression.
pub fn Context::parse_cast_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (CastExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  match tokens {
    [{ kind: Bracket('('), .. }, tok, ..] if self.is_keyword_or_type_name(tok) =>
      //TODO: Skip for we didn't implement type_name parser yet
      // Call parse_cast_expr recursively, so it will return
      ...
    _ => ()
  }
  let (unary_expr, rest) = self.parse_unary_expr(tokens)
  let tokens = init_toks[0:rest.start_offset() - start_offset]
  let cast_to = unary_expr.ctype
  let cast_expr = CastExpr::{ unary_expr, cast_to, tokens }
  (cast_expr, rest)
}

///|
/// AI DO
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
///
/// print like:
///
/// ```plaintext
/// multiplicative expr: \{op}
/// `\{left}
/// `\{right}
/// ```
/// 
/// AI DO
pub fn MultiExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  ...
}

///|
pub enum MultiExprKind {
  CastExpr(CastExpr)
  MulExpr(CastExpr, CastExpr)
  DivExpr(CastExpr, CastExpr)
  ModExpr(CastExpr, CastExpr)
} derive(Eq)

///|
///
/// AI DO
pub fn MultiExpr::parse_multi_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (MultiExpr, ArrayView[Token]) raise ParseError {
  ...
}

///|
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
/// additive expr: \{op}
/// `\{left}
/// `\{right}
/// ```
pub fn AddiExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  ...
}

///|
pub enum AddiExprKind {
  MultiExpr(MultiExpr)
  AddExpr(MultiExpr, MultiExpr)
  SubExpr(MultiExpr, MultiExpr)
} derive(Eq)

///|
///
/// AI DO
pub fn Context::parse_addi_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AddiExpr, ArrayView[Token]) raise ParseError {
  ...
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
  ShlExpr(AddiExpr, AddiExpr)
  ShrExpr(AddiExpr, AddiExpr)
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
/// relational expr: \{op}
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
  LTExpr(ShiftExpr, ShiftExpr)
  GTExpr(ShiftExpr, ShiftExpr)
  LEExpr(ShiftExpr, ShiftExpr)
  GEExpr(ShiftExpr, ShiftExpr)
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
/// equality expr: \{op}
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
  EQExpr(RelationalExpr, RelationalExpr)
  NEExpr(RelationalExpr, RelationalExpr)
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
///
/// TODO: need another test way.
///
/// Test parsing cast expressions (currently only unary expressions are tested
/// since type_name casting is not yet fully implemented)
test "CastExpr Parse Test" {
  let color = false
  let code =
    #|x ; ++y ; *ptr ; -z ; 42 ; 10.0f ; "hello" ; i++ ; --j ;
    #|&var ; ~flag ; !cond ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())
  ctx.add_var("ptr", CType::int().ptr_to())
  ctx.add_var("z", CType::double())
  ctx.add_var("i", CType::int())
  ctx.add_var("j", CType::int())
  ctx.add_var("var", CType::int())
  ctx.add_var("flag", CType::int())
  ctx.add_var("cond", CType::int())

  // Parse `x`
  let (cast_expr, rest) = ctx.parse_cast_expr(ctx.tokens)
  inspect(cast_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `++y`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ++ (int)
      #|`variable y (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `*ptr`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator * (int)
      #|`variable ptr (int *)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `-z`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator - (double)
      #|`variable z (double)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `42`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.to_string(color~), content="int literal 42 (int)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `10.0f`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.to_string(color~), content="float literal 10f (float)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `"hello"`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|string literal "hello" (const char *)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `i++`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ++ (int)
      #|`variable i (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `--j`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator -- (int)
      #|`variable j (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `&var`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator & (int *)
      #|`variable var (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `~flag`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ~ (int)
      #|`variable flag (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `!cond`
  let rest = next_check_point(rest)
  let (cast_expr, _rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ! (int)
      #|`variable cond (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )
}

///|
test "Multiplicative Expr Parse Test" {

}

///|
test "Additive Expr Parse Test" {

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
