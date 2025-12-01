
fn Context::emit_conditional_expr(
  self: Context,
  cond_expr: @parser.ConditionalExpr,
) -> &@IR.Value raise {
  match cond_expr.kind {
    LogicalOrExpr(expr) => self.emit_logical_or_expr(expr)
    ConditionalExpr(cond, then_expr, else_expr) => {
      self.emit_select_expr(cond, then_expr, else_expr)
    }
  }
}

fn Context::emit_select_expr(
  self: Context,
  cond: @parser.LogicalOrExpr,
  then_expr: @parser.Expr,
  else_expr: @parser.ConditionalExpr,
) -> &@IR.Value raise {
  ignore(self)
  ignore(cond)
  ignore(then_expr)
  ignore(else_expr)
  raise Unimplemented("emit_select_expr not implemented")
}
