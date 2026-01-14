///|
#callsite(autofill(loc))
fn[T] codegen_unreachable(loc~ : SourceLoc, msg? : String = "") -> T {
  println("Compiler ICE: reached unreachable code: \{loc}")
  if !msg.is_empty() {
    println("  - \{msg}")
  }
  panic()
}

///|
/// Compute `arr[idx]` element address (for both lvalue and rvalue load)
fn Context::emit_array_access_ptr(
  self : Context,
  arr_expr : @parser.PostfixExpr,
  idx_expr : @parser.Expr,
) -> (&@IR.Value, @parser.CType) raise {
  let idx_raw = self.emit_expr(idx_expr)
  let idx_i32 = self.cast_value_to_ctype(
    idx_raw,
    idx_expr.ctype,
    @parser.CType::int(),
  )
  match arr_expr.ctype.dataKind {
    Ptr(elem_ty) => {
      let base_ptr = self.emit_postfix_expr(arr_expr)
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(idx_i32)
      let elem_ptr = self.builder.createGEP(base_ptr, elem_llvm_ty, indices)
      (elem_ptr, elem_ty)
    }
    Array(elem_ty, _) => {
      let (base_ptr, _) = self.get_lvalue_ptr_from_postfix(arr_expr)
      let arr_llvm_ty = self.ctype_to_llvm_type(arr_expr.ctype)
      let zero = self.llvm_ctx.getConstInt32(0)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(idx_i32)
      let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
      (elem_ptr, elem_ty)
    }
    _ =>
      raise SemanticError("Array subscript target is not an array or pointer")
  }
}
