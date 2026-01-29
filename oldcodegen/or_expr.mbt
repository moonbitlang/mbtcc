///|
fn Context::emit_inclusive_or_expr(
  self : Context,
  expr : @parser.InclusiveOrExpr,
) -> &@IR.Value raise {
  match expr.kind {
    ExclusiveOrExpr(expr) => self.emit_exclusive_or_expr(expr)
    InclusiveOrExpr(left, right) => {
      let left_val = self.emit_inclusive_or_expr(left)
      let right_val = self.emit_exclusive_or_expr(right)
      self.builder.createOr(left_val, right_val)
    }
  }
}

///|
fn Context::emit_logical_or_expr(
  self : Context,
  expr : @parser.LogicalOrExpr,
) -> &@IR.Value raise {
  match expr.kind {
    LogicalAndExpr(expr) => self.emit_logical_and_expr(expr)
    // TODO: This Implementation is actually not correct
    // In Real C, Logical OR (||) is a short-circuiting operator
    // Fix this later
    LogicalOrExpr(left, right) => {
      let left_val = self.emit_logical_or_expr(left)
      let right_val = self.emit_logical_and_expr(right)
      let lbool = self.to_bool(left_val)
      let rbool = self.to_bool(right_val)
      let res_i1 = self.builder.createOr(lbool, rbool)
      self.builder.createZExt(res_i1, self.llvm_ctx.getInt32Ty())
    }
  }
}
