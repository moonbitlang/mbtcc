///|
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
pub enum ConditionalExprKind {
  LogicalOrExpr(LogicalOrExpr)
  ConditionalExpr(LogicalOrExpr, Expr, ConditionalExpr)
} derive(Eq)

///|
///
/// Convert From ConditionalExpr, but check all
/// operands are constant expressions
pub struct ConstantExpr {
  kind : ConditionalExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
test "Conditional Expr Parse Test" {

}

///|
test "Conditional Expr Parse Error Test" {

}
