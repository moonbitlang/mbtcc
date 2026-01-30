///|
fn Context::emit_and_expr(
  self : Context,
  expr : @parser.AndExpr,
) -> &@IR.Value raise {
  match expr.kind {
    EqualityExpr(expr) => self.emit_equality_expr(expr)
    AndExpr(left, right) => {
      let lraw = self.emit_and_expr(left)
      let rraw = self.emit_equality_expr(right)
      let lval = self.cast_value_to_ctype(lraw, left.ctype, expr.ctype)
      let rval = self.cast_value_to_ctype(rraw, right.ctype, expr.ctype)
      self.builder.createAnd(lval, rval)
    }
  }
}

///|
fn Context::emit_logical_and_expr(
  self : Context,
  expr : @parser.LogicalAndExpr,
) -> &@IR.Value raise {
  match expr.kind {
    InclusiveOrExpr(expr) => self.emit_inclusive_or_expr(expr)
    LogicalAndExpr(left, right) => {
      let func = self.current_func.unwrap()
      let left_val = self.emit_logical_and_expr(left)
      let lbool = self.to_bool(left_val)
      let left_bb = self.builder.getInsertBlock().unwrap()
      let rhs_bb = func.addBasicBlock()
      let merge_bb = func.addBasicBlock()
      self.builder.createCondBr(lbool, rhs_bb, merge_bb) |> ignore

      // rhs
      self.builder.setInsertPoint(rhs_bb)
      let right_val = self.emit_inclusive_or_expr(right)
      let rbool = self.to_bool(right_val)
      let rhs_end = self.builder.getInsertBlock().unwrap()
      self.builder.createBr(merge_bb) |> ignore

      // merge
      self.builder.setInsertPoint(merge_bb)
      let phi = self.builder.createPHI(self.llvm_ctx.getInt1Ty())
      phi.addIncoming(self.llvm_ctx.getConstFalse(), left_bb) |> ignore
      phi.addIncoming(rbool, rhs_end) |> ignore
      self.builder.createZExt(phi, self.llvm_ctx.getInt32Ty())
    }
  }
}
