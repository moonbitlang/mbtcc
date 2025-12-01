
fn Context::emit_equality_expr(
  self: Context,
  expr: @parser.EqualityExpr
) -> &@IR.Value raise {
  match expr.kind {
    RelationalExpr(expr) => self.emit_relational_expr(expr)
    // TODO: This Implementation is incorrect
    // when comparing floating point numbers, we need to use
    // createFCmpOEQ or createFCmpONE based on the type
    // This is a temporary implementation
    EQExpr(left, right) => {
      let left_val = self.emit_equality_expr(left)
      let right_val = self.emit_relational_expr(right)
      self.builder.createICmpEQ(left_val, right_val)
    }
    NEExpr(left, right) => {
      let left_val = self.emit_equality_expr(left)
      let right_val = self.emit_relational_expr(right)
      self.builder.createICmpNE(left_val, right_val)
    }
  }
}
