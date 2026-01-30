///|
fn Context::emit_expr(self : Context, expr : @parser.Expr) -> &@IR.Value raise {
  let { assign_exprs, .. } = expr
  let vals = assign_exprs.map(assign_expr => self.emit_assign_expr(assign_expr))
  vals.last().unwrap()
}
