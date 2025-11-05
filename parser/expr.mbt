///|
pub struct Expr {
  assign_exprs : Array[AssignExpr]
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Expr with equal(self, other) {
  self.assign_exprs == other.assign_exprs
}

///|
pub fn Expr::is_constant(self : Self) -> Bool {
  for expr in self.assign_exprs {
    if !expr.is_constant() {
      return false
    }
  }
  true
}

///|
pub fn Expr::eval_as_int(self : Self) -> Int raise ParseError {
  if self.assign_exprs.length() == 0 {
    raise ParseError(
      self.tokens[0],
      "Cannot evaluate empty expression as integer",
    )
  }
  // Evaluate the last assign expression
  self.assign_exprs.last().unwrap().eval_as_int()
}
