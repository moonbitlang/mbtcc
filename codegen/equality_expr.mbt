///|
fn Context::emit_equality_expr(
  self : Context,
  expr : @parser.EqualityExpr,
) -> &@IR.Value raise {
  match expr.kind {
    RelationalExpr(expr) => self.emit_relational_expr(expr)
    EQExpr(left, right) => self.emit_eq_compare(left, right, is_eq=true)
    NEExpr(left, right) => self.emit_eq_compare(left, right, is_eq=false)
  }
}

///|
fn Context::emit_eq_compare(
  self : Context,
  left : @parser.EqualityExpr,
  right : @parser.RelationalExpr,
  is_eq~ : Bool,
) -> &@IR.Value raise {
  fn is_const_zero_eq(expr : @parser.EqualityExpr) -> Bool {
    try expr.eval_as_int() catch {
      _ => false
    } noraise {
      v => v == 0
    }
  }
  fn is_const_zero_rel(expr : @parser.RelationalExpr) -> Bool {
    try expr.eval_as_int() catch {
      _ => false
    } noraise {
      v => v == 0
    }
  }
  let lraw = self.emit_equality_expr(left)
  let rraw = self.emit_relational_expr(right)
  let l_is_ptr = left.ctype.dataKind is Ptr(_)
  let r_is_ptr = right.ctype.dataKind is Ptr(_)
  if l_is_ptr != r_is_ptr {
    let (ptr_val, ptr_ty, int_is_zero) = if l_is_ptr {
      (lraw, left.ctype, is_const_zero_rel(right))
    } else {
      (rraw, right.ctype, is_const_zero_eq(left))
    }
    if int_is_zero {
      let common = @parser.CType::ulong()
      let lval = self.cast_value_to_ctype(ptr_val, ptr_ty, common)
      let rval = self.const_zero_value(self.ctype_to_llvm_type(common))
      let cmp = if is_eq {
        self.builder.createICmpEQ(lval, rval)
      } else {
        self.builder.createICmpNE(lval, rval)
      }
      return self.builder.createZExt(cmp, self.llvm_ctx.getInt32Ty())
    }
    // Fallback: compare as unsigned long
    let common = @parser.CType::ulong()
    let lval = self.cast_value_to_ctype(lraw, left.ctype, common)
    let rval = self.cast_value_to_ctype(rraw, right.ctype, common)
    let cmp = if is_eq {
      self.builder.createICmpEQ(lval, rval)
    } else {
      self.builder.createICmpNE(lval, rval)
    }
    return self.builder.createZExt(cmp, self.llvm_ctx.getInt32Ty())
  }
  let common = if l_is_ptr && r_is_ptr {
    @parser.CType::ulong()
  } else {
    match left.ctype.common_type(right.ctype) {
      Some(t) => t
      None => {
        let msg = "parser produced equality comparison with incompatible types " +
          " '\{left.ctype}' and '\{right.ctype}'"
        codegen_unreachable(msg~)
      }
    }
  }
  let lval = self.cast_value_to_ctype(lraw, left.ctype, common)
  let rval = self.cast_value_to_ctype(rraw, right.ctype, common)
  let is_floating = is_floating_kind(common.dataKind)
  let cmp = match (is_floating, is_eq) {
    (true, true) => self.builder.createFCmpOEQ(lval, rval)
    (true, false) => self.builder.createFCmpONE(lval, rval)
    (false, true) => self.builder.createICmpEQ(lval, rval)
    (false, false) => self.builder.createICmpNE(lval, rval)
  }
  self.builder.createZExt(cmp, self.llvm_ctx.getInt32Ty())
}
