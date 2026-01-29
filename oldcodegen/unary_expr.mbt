///|
fn Context::emit_unary_expr(
  self : Context,
  expr : @parser.UnaryExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PostfixExpr(expr) => self.emit_postfix_expr(expr)
    PreInc(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_unary(expr)
      let (_, new_val) = self.apply_inc_dec(ptr, ctype, is_inc=true)
      new_val
    }
    PreDec(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_unary(expr)
      let (_, new_val) = self.apply_inc_dec(ptr, ctype, is_inc=false)
      new_val
    }
    AddrOf(expr) =>
      // & operand must be an lvalue. We accept lvalues that come from a unary expression.
      match expr.kind {
        UnaryExpr(u) => {
          let (ptr, _) = self.get_lvalue_ptr_from_unary(u)
          ptr
        }
        _ => raise SemanticError("Expression is not an assignable lvalue")
      }
    Deref(inner) => {
      let ptr_val = self.emit_cast_expr(inner)
      match expr.ctype.dataKind {
        Function(_, _, ..) => ptr_val
        Array(_, _) => {
          let arr_llvm_ty = self.ctype_to_llvm_type(expr.ctype)
          let zero = self.llvm_ctx.getConstInt32(0)
          let indices : Array[&@IR.Value] = Array::new()
          indices.push(zero)
          indices.push(zero)
          self.builder.createGEP(ptr_val, arr_llvm_ty, indices)
        }
        _ => {
          let llvm_ty = self.ctype_to_llvm_type(expr.ctype)
          self.builder.createLoad(llvm_ty, ptr_val)
        }
      }
    }
    Posate(inner) => self.emit_cast_expr(inner)
    Negate(expr) => {
      let val = self.emit_cast_expr(expr)
      if val.getType().isFloatingPointTy() {
        self.builder.createFNeg(val)
      } else {
        let zero = self.llvm_ctx.getConstZero(val.getType())
        self.builder.createSub(zero, val)
      }
    }
    BitNot(expr) => {
      let val = self.emit_cast_expr(expr)
      self.builder.createNot(val)
    }
    LogicalNot(expr) => {
      let val = self.emit_cast_expr(expr)
      let cond = self.to_bool(val) // i1: x != 0
      let inv = self.builder.createXor(cond, self.llvm_ctx.getConstTrue())
      self.builder.createZExt(inv, self.llvm_ctx.getInt32Ty())
    }
    SizeofExpr(expr) => {
      let sz = self.ctype_sizeof_bytes(expr.ctype)
      self.llvm_ctx.getConstInt64(sz)
    }
    SizeofType(ty) => {
      let sz = self.ctype_sizeof_bytes(ty)
      self.llvm_ctx.getConstInt64(sz)
    }
    Alignof(ty) => {
      ignore(ty)
      raise Unimplemented("Alignof type codegen is not implemented yet")
    }
  }
}
