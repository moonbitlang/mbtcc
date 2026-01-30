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
    LogicalOrExpr(left, right) => {
      let func = self.current_func.unwrap()
      let left_val = self.emit_logical_or_expr(left)
      let lbool = self.to_bool(left_val)
      let left_bb = self.builder.getInsertBlock().unwrap()
      let rhs_bb = func.addBasicBlock()
      let merge_bb = func.addBasicBlock()
      self.builder.createCondBr(lbool, merge_bb, rhs_bb) |> ignore

      // rhs
      self.builder.setInsertPoint(rhs_bb)
      let right_val = self.emit_logical_and_expr(right)
      let rbool = self.to_bool(right_val)
      let rhs_end = self.builder.getInsertBlock().unwrap()
      self.builder.createBr(merge_bb) |> ignore

      // merge
      self.builder.setInsertPoint(merge_bb)
      let phi = self.builder.createPHI(self.llvm_ctx.getInt1Ty())
      phi.addIncoming(self.llvm_ctx.getConstTrue(), left_bb) |> ignore
      phi.addIncoming(rbool, rhs_end) |> ignore
      self.builder.createZExt(phi, self.llvm_ctx.getInt32Ty())
    }
  }
}
