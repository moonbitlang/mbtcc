///|
fn Context::emit_multiplicative_expr(
  self : Context,
  expr : @parser.MultiExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation didn't handle type promotion.
  // Besides, it didn't consider unsigned and floating point types.
  match expr.kind {
    CastExpr(expr) => self.emit_cast_expr(expr)
    MulExpr(left, right) => {
      let left_val = self.emit_multiplicative_expr(left)
      let right_val = self.emit_cast_expr(right)
      self.builder.createMul(left_val, right_val)
    }
    DivExpr(left, right) => {
      let left_val = self.emit_multiplicative_expr(left)
      let right_val = self.emit_cast_expr(right)
      self.builder.createSDiv(left_val, right_val)
    }
    ModExpr(left, right) => {
      let left_val = self.emit_multiplicative_expr(left)
      let right_val = self.emit_cast_expr(right)
      self.builder.createSRem(left_val, right_val)
    }
  }
}
