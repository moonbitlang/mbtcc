///|
fn Context::emit_postfix_expr(
  self : Self,
  expr : @parser.PostfixExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PrimExpr(expr) => self.emit_prim_expr(expr)
    ArrayAccess(expr, idx_expr) => {
      let (elem_ptr, elem_ty) = self.emit_array_access_ptr(expr, idx_expr)
      match elem_ty.dataKind {
        Array(_, _) => {
          let arr_llvm_ty = self.ctype_to_llvm_type(elem_ty)
          let zero = self.llvm_ctx.getConstInt32(0)
          let indices : Array[&@IR.Value] = Array::new()
          indices.push(zero)
          indices.push(zero)
          self.builder.createGEP(elem_ptr, arr_llvm_ty, indices)
        }
        _ => {
          let llvm_ty = self.ctype_to_llvm_type(elem_ty)
          self.builder.createLoad(llvm_ty, elem_ptr)
        }
      }
    }
    FuncCall(func_expr, arg_exprs) => self.emit_func_call(func_expr, arg_exprs)
    MemberAccess(expr, member_name) => {
      let base_val = self.emit_postfix_expr(expr)
      let (idx, _fty) = struct_field_index_and_type(expr.ctype, member_name)
      self.builder.createExtractValue(base_val, [idx])
    }
    PtrMemberAccess(expr, member_name) => {
      guard expr.ctype.dataKind is Ptr(inner) else {
        raise SemanticError("Pointer member access on non-pointer type")
      }
      let (idx, fty) = struct_field_index_and_type(inner, member_name)
      let base_ptr = self.emit_postfix_expr(expr)
      let st_llvm_ty = self.ctype_to_llvm_type(inner)
      let zero = self.llvm_ctx.getConstInt32(0)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(self.llvm_ctx.getConstInt32(idx))
      let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
      self.builder.createLoad(self.ctype_to_llvm_type(fty), field_ptr)
    }
    PostInc(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_postfix(expr)
      let (old_val, _) = self.apply_inc_dec(ptr, ctype, is_inc=true)
      old_val
    }
    PostDec(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_postfix(expr)
      let (old_val, _) = self.apply_inc_dec(ptr, ctype, is_inc=false)
      old_val
    }
  }
}

///|
fn Context::emit_func_call(
  self : Self,
  func_expr : @parser.PostfixExpr,
  arg_exprs : Array[@parser.AssignExpr],
) -> &@IR.Value raise {
  let func_value = self.emit_postfix_expr(func_expr)
  // The function value should be a Function
  // TODO: Handle function pointers later
  match func_value.tryAsGlobalValueEnum() {
    Some(Function(func)) => {
      let args : Array[&@IR.Value] = Array::new()
      let decl = self.func_decls.get(func.getNameOrSlotStr())
      let (params, is_variadic) = match decl {
        Some({ dataKind: Function(params, _, is_variadic~), .. }) =>
          (params, is_variadic)
        _ => (Array::new(), false)
      }
      let fixed_n = params.length()
      for i in 0..<arg_exprs.length() {
        let arg_expr = arg_exprs[i]
        let raw = self.emit_assign_expr(arg_expr)
        let casted = if i < fixed_n {
          let (param_ty, _) = params[i]
          self.cast_value_to_ctype(raw, arg_expr.ctype, param_ty)
        } else if is_variadic {
          match arg_expr.ctype.dataKind {
            Char | UChar | Int16 | UInt16 =>
              self.cast_value_to_ctype(
                raw,
                arg_expr.ctype,
                @parser.CType::int(),
              )
            Float =>
              self.cast_value_to_ctype(
                raw,
                arg_expr.ctype,
                @parser.CType::double(),
              )
            _ => raw
          }
        } else {
          raw
        }
        args.push(casted)
      }
      self.builder.createCall(func, args)
    }
    _ => {
      let (param_tys, ret_ty, is_variadic) = match func_expr.ctype.dataKind {
        Function(params, ret_ty, is_variadic~) => (params, ret_ty, is_variadic)
        Ptr({ dataKind: Function(params, ret_ty, is_variadic~), .. }) =>
          (params, ret_ty, is_variadic)
        _ => raise SemanticError("Function call target is not a function")
      }
      let llvm_param_tys : Array[&@IR.Type] = Array::new()
      for p in param_tys {
        let (pty, _) = p
        llvm_param_tys.push(self.ctype_to_llvm_type(pty))
      }
      let llvm_ret_ty = self.ctype_to_llvm_type(ret_ty)
      let fty = self.llvm_ctx.getFunctionType(
        llvm_ret_ty,
        llvm_param_tys,
        isVarArg=is_variadic,
      )
      let args : Array[&@IR.Value] = Array::new()
      let fixed_n = param_tys.length()
      for i in 0..<arg_exprs.length() {
        let arg_expr = arg_exprs[i]
        let raw = self.emit_assign_expr(arg_expr)
        let casted = if i < fixed_n {
          let (pty, _) = param_tys[i]
          self.cast_value_to_ctype(raw, arg_expr.ctype, pty)
        } else if is_variadic {
          match arg_expr.ctype.dataKind {
            Char | UChar | Int16 | UInt16 =>
              self.cast_value_to_ctype(
                raw,
                arg_expr.ctype,
                @parser.CType::int(),
              )
            Float =>
              self.cast_value_to_ctype(
                raw,
                arg_expr.ctype,
                @parser.CType::double(),
              )
            _ => raw
          }
        } else {
          raw
        }
        args.push(casted)
      }
      self.builder.createCallPtr(func_value, fty, args)
    }
  }
}
