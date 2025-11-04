///|
pub struct AndExpr {
  kind : AndExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AndExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum AndExprKind {
  EqualityExpr(EqualityExpr)
  AndExpr(AndExpr, EqualityExpr)
} derive(Eq)

///|
pub struct LogicalAndExpr {
  kind : LogicalAndExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for LogicalAndExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum LogicalAndExprKind {
  InclusiveOrExpr(InclusiveOrExpr)
  LogicalAndExpr(LogicalAndExpr, InclusiveOrExpr)
} derive(Eq)

///|
test "And Expr Parse Test" {

}

///|
test "And Expr Parse Error Test" {

}

///|
test "Logical And Expr Parse Test" {

}

///|
test "Logical And Expr Parse Error Test" {

}
