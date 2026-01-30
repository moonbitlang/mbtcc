///|
fn Context::emit_exclusive_or_expr(
  self : Context,
  expr : @parser.ExclusiveOrExpr,
) -> &@IR.Value raise {
  match expr.kind {
    AndExpr(expr) => self.emit_and_expr(expr)
    ExclusiveOrExpr(left, right) => {
      let lraw = self.emit_exclusive_or_expr(left)
      let rraw = self.emit_and_expr(right)
      let lval = self.cast_value_to_ctype(lraw, left.ctype, expr.ctype)
      let rval = self.cast_value_to_ctype(rraw, right.ctype, expr.ctype)
      self.builder.createXor(lval, rval)
    }
  }
}
