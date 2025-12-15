///|
fn Context::emit_postfix_expr(
  self : Self,
  expr : @parser.PostfixExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PrimExpr(expr) => self.emit_prim_expr(expr)
    ArrayAccess(expr, idx_expr) => {
      ignore(expr)
      ignore(idx_expr)
      raise Unimplemented("Array access not implemented yet")
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
  // Evaluate arguments
  let args : Array[&@IR.Value] = Array::new()
  for arg_expr in arg_exprs {
    let arg_value = self.emit_assign_expr(arg_expr)
    args.push(arg_value)
  }
  // The function value should be a Function
  // TODO: Handle function pointers later
  match func_value.tryAsGlobalValueEnum() {
    Some(Function(func)) => self.builder.createCall(func, args)
    _ => raise SemanticError("Function call target is not a function")
  }
}
