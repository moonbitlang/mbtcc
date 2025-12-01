///|
fn Context::emit_shift_expr(
  self : Context,
  expr : @parser.ShiftExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation is incorrect.
  // first it does not handle floating point numbers correctly.
  // second, it does not handle Unsigned Right Shift correctly for signed integers.
  match expr.kind {
    AddiExpr(expr) => self.emit_additive_expr(expr)
    ShlExpr(left, right) => {
      let left_val = self.emit_shift_expr(left)
      let right_val = self.emit_additive_expr(right)
      self.builder.createShl(left_val, right_val)
    }
    ShrExpr(left, right) => {
      let left_val = self.emit_shift_expr(left)
      let right_val = self.emit_additive_expr(right)
      self.builder.createLShr(left_val, right_val)
    }
  }
}
