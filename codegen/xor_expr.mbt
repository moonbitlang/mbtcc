
fn Context::emit_exclusive_or_expr(
  self: Context,
  expr: @parser.ExclusiveOrExpr
) -> &@IR.Value raise {
  match expr.kind {
    AndExpr(expr) => self.emit_and_expr(expr)
    ExclusiveOrExpr(left, right) => {
      let left_val = self.emit_exclusive_or_expr(left)
      let right_val = self.emit_and_expr(right)
      self.builder.createXor(left_val, right_val)
    }
  }
}
