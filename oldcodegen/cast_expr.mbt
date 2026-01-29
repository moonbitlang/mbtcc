///|
fn Context::emit_cast_expr(
  self : Context,
  expr : @parser.CastExpr,
) -> &@IR.Value raise {
  match expr.kind {
    UnaryExpr(expr) => self.emit_unary_expr(expr)
    CastTo(target_ctype, inner_expr) => {
      let inner_val = self.emit_cast_expr(inner_expr)
      self.cast_value_to_ctype(inner_val, inner_expr.ctype, target_ctype)
    }
  }
}
