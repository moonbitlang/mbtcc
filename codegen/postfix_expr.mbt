///|
fn Context::emit_postfix_expr(
  self : Self,
  expr : @parser.PostfixExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PrimExpr(expr) => self.emit_prim_expr(expr)
    ArrayAccess(expr, idx_expr) => {
      let (elem_ptr, elem_ty) = self.emit_array_access_ptr(expr, idx_expr)
      let llvm_ty = self.ctype_to_llvm_type(elem_ty)
      self.builder.createLoad(llvm_ty, elem_ptr)
    }
    FuncCall(func_expr, arg_exprs) => self.emit_func_call(func_expr, arg_exprs)
    MemberAccess(expr, member_name) => {
      ignore(expr)
      ignore(member_name)
      raise Unimplemented("Member access not implemented yet")
    }
    PtrMemberAccess(expr, member_name) => {
      ignore(expr)
      ignore(member_name)
      raise Unimplemented("Pointer member access not implemented yet")
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
    _ => raise SemanticError("Function call target is not a function")
  }
}
