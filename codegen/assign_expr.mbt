///|
fn Context::emit_assign_expr(
  self : Context,
  assign_expr : @parser.AssignExpr,
) -> &@IR.Value raise {
  match assign_expr.kind {
    Conditional(cond_expr) => self.emit_conditional_expr(cond_expr)
    Assign(left, assign_op, right) =>
      self.emit_assignment(left, assign_op, right)
  }
}

///|
fn Context::emit_assignment(
  self : Context,
  left : @parser.UnaryExpr,
  assign_op : @parser.AssignOp,
  right : @parser.AssignExpr,
) -> &@IR.Value raise {
  ignore(self)
  ignore(left)
  ignore(right)
  ignore(assign_op)
  raise Unimplemented("emit_assignment not implemented")
}
