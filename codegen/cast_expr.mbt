///|
fn Context::emit_cast_expr(
  self : Context,
  expr : @parser.CastExpr,
) -> &@IR.Value raise {
  match expr.kind {
    UnaryExpr(expr) => self.emit_unary_expr(expr)
    CastTo(_) =>
      raise Unimplemented("Cast expression codegen is not implemented yet")
  }
}
