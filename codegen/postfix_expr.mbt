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
    FuncCall(expr, arg_exprs) => {
      ignore(expr)
      ignore(arg_exprs)
      raise Unimplemented("Function calls not implemented yet")
    }
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
      ignore(expr)
      raise Unimplemented("Postfix increment not implemented yet")
    }
    PostDec(expr) => {
      ignore(expr)
      raise Unimplemented("Postfix decrement not implemented yet")
    }
  }
}
