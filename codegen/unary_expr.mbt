///|
fn Context::emit_unary_expr(
  self : Context,
  expr : @parser.UnaryExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PostfixExpr(expr) => self.emit_postfix_expr(expr)
    PreInc(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_unary(expr)
      let (_, new_val) = self.apply_inc_dec(ptr, ctype, true)
      new_val
    }
    PreDec(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_unary(expr)
      let (_, new_val) = self.apply_inc_dec(ptr, ctype, false)
      new_val
    }
    AddrOf(expr) => {
      let (ptr, _) = self.get_lvalue_ptr_from_unary(expr)
      ptr
    }
    Deref(inner) => {
      let ptr_val = self.emit_unary_expr(inner)
      let llvm_ty = self.ctype_to_llvm_type(expr.ctype)
      self.builder.createLoad(llvm_ty, ptr_val)
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
