///|
pub struct ExclusiveOrExpr {
  kind : ExclusiveOrExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ExclusiveOrExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum ExclusiveOrExprKind {
  AndExpr(AndExpr)
  ExclusiveOrExpr(ExclusiveOrExpr, AndExpr)
} derive(Eq)

///|
test "Exclusive Or Expr Parse Test" {

}

///|
test "Exclusive Or Expr Parse Error Test" {

}
