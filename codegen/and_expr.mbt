///|
fn Context::emit_and_expr(
  self : Context,
  expr : @parser.AndExpr,
) -> &@IR.Value raise {
  match expr.kind {
    EqualityExpr(expr) => self.emit_equality_expr(expr)
    AndExpr(left, right) => {
      let left_val = self.emit_and_expr(left)
      let right_val = self.emit_equality_expr(right)
      self.builder.createAnd(left_val, right_val)
    }
  }
}

///|
fn Context::emit_logical_and_expr(
  self : Context,
  expr : @parser.LogicalAndExpr,
) -> &@IR.Value raise {
  match expr.kind {
    InclusiveOrExpr(expr) => self.emit_inclusive_or_expr(expr)
    // TODO: This Implementation is actually not correct
    // In Real C, Logical AND (&&) is a short-circuiting operator
    // Fix this later
    LogicalAndExpr(left, right) => {
      let left_val = self.emit_logical_and_expr(left)
      let right_val = self.emit_inclusive_or_expr(right)
      self.builder.createAnd(left_val, right_val)
    }
  }
}
