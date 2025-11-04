///|
pub struct InclusiveOrExpr {
  kind : InclusiveOrExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for InclusiveOrExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum InclusiveOrExprKind {
  ExclusiveOrExpr(ExclusiveOrExpr)
  InclusiveOrExpr(InclusiveOrExpr, ExclusiveOrExpr)
} derive(Eq)

///|
pub struct LogicalOrExpr {
  kind : LogicalOrExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for LogicalOrExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum LogicalOrExprKind {
  LogicalAndExpr(LogicalAndExpr)
  LogicalOrExpr(LogicalOrExpr, LogicalAndExpr)
} derive(Eq)

///|
test "Inclusive Or Expr Parse Test" {

}

///|
test "Inclusive Or Expr Parse Error Test" {

}

///|
test "Logical Or Expr Parse Test" {

}

///|
test "Logical Or Expr Parse Error Test" {

}
