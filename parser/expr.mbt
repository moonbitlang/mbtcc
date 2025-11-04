///|
pub struct Expr {
  assign_exprs : Array[AssignExpr]
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Expr with equal(self, other) {
  self.assign_exprs == other.assign_exprs
}
