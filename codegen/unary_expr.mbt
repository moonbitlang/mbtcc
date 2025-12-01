///|
fn Context::emit_unary_expr(
  self : Context,
  expr : @parser.UnaryExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PostfixExpr(expr) => self.emit_postfix_expr(expr)
    PreInc(expr) => {
      ignore(expr)
      raise Unimplemented(
        "Pre-increment expression codegen is not implemented yet",
      )
    }
    PreDec(expr) => {
      ignore(expr)
      raise Unimplemented(
        "Pre-decrement expression codegen is not implemented yet",
      )
    }
    AddrOf(expr) => {
      ignore(expr)
      raise Unimplemented(
        "Address-of expression codegen is not implemented yet",
      )
    }
    Deref(expr) => {
      ignore(expr)
      raise Unimplemented(
        "Dereference expression codegen is not implemented yet",
      )
    }
    Negate(expr) => {
      let val = self.emit_unary_expr(expr)
      if val.getType().isFloatingPointTy() {
        self.builder.createFNeg(val)
      } else {
        let zero = self.llvm_ctx.getConstZero(val.getType())
        self.builder.createSub(zero, val)
      }
    }
    BitNot(expr) => {
      let val = self.emit_unary_expr(expr)
      let one = self.llvm_ctx.getConstOne(val.getType())
      self.builder.createXor(one, val)
    }
    LogicalNot(expr) => {
      let val = self.emit_unary_expr(expr)
      let zero = self.llvm_ctx.getConstFalse()
      self.builder.createICmpEQ(val, zero)
    }
    SizeofExpr(expr) => {
      ignore(expr)
      raise Unimplemented("Sizeof expression codegen is not implemented yet")
    }
    SizeofType(ty) => {
      ignore(ty)
      raise Unimplemented("Sizeof type codegen is not implemented yet")
    }
    Alignof(ty) => {
      ignore(ty)
      raise Unimplemented("Alignof type codegen is not implemented yet")
    }
  }
}
