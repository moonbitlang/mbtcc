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
pub fn Context::parse_relational_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (RelationalExpr, ArrayView[Token]) raise ParseError {
  ...
}

///|
test "Relational Expr Parse Test" {

}

///|
test "Relational Expr Parse Error Test" {

}
