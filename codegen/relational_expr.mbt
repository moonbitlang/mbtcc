

fn Context::emit_relational_expr(
  self: Context,
  expr: @parser.RelationalExpr
) -> &@IR.Value raise {
  // TODO: This Implementation is incorrect
  // when comparing floating point numbers, we need to use
  // createFCmpOLT, createFCmpOGT, createFCmpOLE, createFCmpOGE
  // based on the type
  match expr.kind {
    ShiftExpr(expr) => self.emit_shift_expr(expr)
    LTExpr(left, right) => {
      let left_val = self.emit_relational_expr(left)
      let right_val = self.emit_shift_expr(right)
      self.builder.createICmpSLT(left_val, right_val)
    }
    GTExpr(left, right) => {
      let left_val = self.emit_relational_expr(left)
      let right_val = self.emit_shift_expr(right)
      self.builder.createICmpSGT(left_val, right_val)
    }
    LEExpr(left, right) => {
      let left_val = self.emit_relational_expr(left)
      let right_val = self.emit_shift_expr(right)
      self.builder.createICmpSLE(left_val, right_val)
    }
    GEExpr(left, right) => {
      let left_val = self.emit_relational_expr(left)
      let right_val = self.emit_shift_expr(right)
      self.builder.createICmpSGE(left_val, right_val)
    }
  }
}
