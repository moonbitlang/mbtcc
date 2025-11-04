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
pub fn ShiftExpr::to_string(self : Self, color? : Bool = true) -> String {
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
pub fn RelationalExpr::to_string(self : Self, color? : Bool = true) -> String {
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
pub fn EqualityExpr::to_string(self : Self, color? : Bool = true) -> String {
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
