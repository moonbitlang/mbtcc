

pub fn Context::emit_additive_expr(
  self: Context,
  expr: @parser.AddiExpr
) -> &@IR.Value raise {
  // TODO: This Implementation didn't handle type promotion.
  match expr.kind {
    MultiExpr(expr) => self.emit_multiplicative_expr(expr)
    AddExpr(left, right) => {
      let left_val = self.emit_additive_expr(left)
      let right_val = self.emit_multiplicative_expr(right)
      self.builder.createAdd(left_val, right_val)
    }
    SubExpr(left, right) => {
      let left_val = self.emit_additive_expr(left)
      let right_val = self.emit_multiplicative_expr(right)
      self.builder.createSub(left_val, right_val)
    }
  }
}
