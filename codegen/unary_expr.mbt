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
    LabelAddr(label, func_name) => {
      let func = match self.llvm_mod.getFunction(func_name) {
        Some(f) => f
        None =>
          raise SemanticError("Function '\{func_name}' not found for label address")
      }
      let key = "\{func_name}::\{label}"
      let bb = match self.label_global.get(key) {
        Some(b) => b
        None => {
          // Fallback: if we are in the same function, create/lookup label.
          if self.current_func is Some(cf) && cf.getName() == func_name {
            self.get_label(label)
          } else {
            raise SemanticError("Label '\{label}' not found in function '\{func_name}'")
          }
        }
      }
      (func.blockAddress(bb) : &@IR.Value)
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
          (self.builder.createGEP(ptr_val, arr_llvm_ty, indices) : &@IR.Value)
        }
        _ => {
          let llvm_ty = self.ctype_to_llvm_type(expr.ctype)
          (self.builder.createLoad(llvm_ty, ptr_val) : &@IR.Value)
        }
      }
    }
    Posate(inner) => self.emit_cast_expr(inner)
    Negate(expr) => {
      let val = self.emit_cast_expr(expr)
      if val.getType().isFloatingPointTy() {
        self.builder.createFNeg(val)
      } else {
        let zero = self.const_zero_value(val.getType())
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
    BuiltinVaArg(list_expr, ty) => {
      let (list_ptr, _) = self.get_lvalue_ptr_from_unary(list_expr)
      let llvm_ty = self.ctype_to_llvm_type(ty)
      if is_aggregate_type(ty) {
        let cur = (self.builder.createLoad(self.llvm_ctx.getPtrTy(), list_ptr) : &@IR.Value)
        let size = self.ctype_sizeof_bytes(ty)
        let size_val = self.llvm_ctx.getConstInt64(size)
        let step = ((size + 7) / 8) * 8
        let step_val = self.llvm_ctx.getConstInt64(step)
        let idxs : Array[&@IR.Value] = Array::new()
        idxs.push(step_val)
        let next = (self.builder.createGEP(cur, self.llvm_ctx.getInt8Ty(), idxs) : &@IR.Value)
        self.builder.createStore(next, list_ptr) |> ignore
        let tmp = self.builder.createAlloca(llvm_ty)
        let dl = self.llvm_mod.getDataLayout()
        let align = dl.getTypeAlignment(llvm_ty)
        self.builder.createMemCpy(tmp, align, cur, 8, size_val) |> ignore
        (self.builder.createLoad(llvm_ty, tmp) : &@IR.Value)
      } else {
        self.builder.createVAArg(list_ptr, llvm_ty)
      }
    }
  }
}
