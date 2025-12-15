///|
fn Context::emit_prim_expr(
  self : Context,
  expr : @parser.PrimExpr,
) -> &@IR.Value raise {
  let { llvm_ctx, .. } = self
  match expr.kind {
    Ident(name) => {
      guard self.var_env.get(name) is Some(val) else {
        raise SemanticError("Undefined identifier: '\{name}'")
      }
      // Check if we have type information for this variable
      // If we do, it means it's a local variable that needs to be loaded
      match self.var_types.get(name) {
        Some(cty) => {
          let llvm_ty = self.ctype_to_llvm_type(cty)
          self.builder.createLoad(llvm_ty, val)
        }
        None => val // Function parameters or other direct values
      }
    }
    Char(c) => llvm_ctx.getConstInt8(c.to_int())
    Int(i) => llvm_ctx.getConstInt32(i)
    Long(i) => llvm_ctx.getConstInt64(i)
    LongLong(i) => llvm_ctx.getConstInt64(i)
    UInt(i) => llvm_ctx.getConstInt32(i.reinterpret_as_int())
    ULong(i) => llvm_ctx.getConstInt64(i.reinterpret_as_int64())
    ULongLong(i) => llvm_ctx.getConstInt64(i.reinterpret_as_int64())
    Float(f) => llvm_ctx.getConstFloat(f)
    Double(f) => llvm_ctx.getConstDouble(f)
    Strings(strs) => {
      let full_str = strs.join("")
      self.builder.createGlobalString(full_str)
    }
    Paren(expr) => self.emit_expr(expr)
  }
}
