///|
fn Context::emit_relational_expr(
  self : Context,
  expr : @parser.RelationalExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation is incorrect
  // when comparing floating point numbers, we need to use
  // createFCmpOLT, createFCmpOGT, createFCmpOLE, createFCmpOGE
  // based on the type
  match expr.kind {
    ShiftExpr(expr) => self.emit_shift_expr(expr)
    LTExpr(left, right) => self.emit_rel_compare(left, right, "lt")
    GTExpr(left, right) => self.emit_rel_compare(left, right, "gt")
    LEExpr(left, right) => self.emit_rel_compare(left, right, "le")
    GEExpr(left, right) => self.emit_rel_compare(left, right, "ge")
  }
}

///|
fn Context::emit_rel_compare(
  self : Context,
  left : @parser.RelationalExpr,
  right : @parser.ShiftExpr,
  cmp : String,
) -> &@IR.Value raise {
  let lraw = self.emit_relational_expr(left)
  let rraw = self.emit_shift_expr(right)

  // Pointer comparison: MoonLLVM's `createICmp*` expects integer operands, so we
  // compare pointers by casting them to `unsigned long` (i64) first.
  let left_is_ptr = left.ctype.dataKind is Ptr(_) ||
    left.ctype.dataKind is Array(_, _)
  let right_is_ptr = right.ctype.dataKind is Ptr(_) ||
    right.ctype.dataKind is Array(_, _)
  if left_is_ptr && right_is_ptr {
    fn decay_ptr(t : @parser.CType) -> @parser.CType {
      match t.dataKind {
        Array(elem, _) => elem.ptr_to()
        _ => t
      }
    }

    let ulong_ty = @parser.CType::ulong()
    let lval = self.cast_value_to_ctype(lraw, decay_ptr(left.ctype), ulong_ty)
    let rval = self.cast_value_to_ctype(rraw, decay_ptr(right.ctype), ulong_ty)
    let res = match cmp {
      "lt" => self.builder.createICmpULT(lval, rval)
      "gt" => self.builder.createICmpUGT(lval, rval)
      "le" => self.builder.createICmpULE(lval, rval)
      "ge" => self.builder.createICmpUGE(lval, rval)
      _ => codegen_unreachable()
    }
    return self.builder.createZExt(res, self.llvm_ctx.getInt32Ty())
  }
  let common = match left.ctype.common_type(right.ctype) {
    Some(t) => t
    None => {
      let msg = "parser produced relational comparison with incompatible types '\{left.ctype}' and '\{right.ctype}'"
      codegen_unreachable(msg~)
    }
  }
  let lval = self.cast_value_to_ctype(lraw, left.ctype, common)
  let rval = self.cast_value_to_ctype(rraw, right.ctype, common)
  if is_floating_kind(common.dataKind) {
    let res = match cmp {
      "lt" => self.builder.createFCmpOLT(lval, rval)
      "gt" => self.builder.createFCmpOGT(lval, rval)
      "le" => self.builder.createFCmpOLE(lval, rval)
      "ge" => self.builder.createFCmpOGE(lval, rval)
      _ => codegen_unreachable()
    }
    // C 里关系运算结果类型是 int（0 或 1）
    self.builder.createZExt(res, self.llvm_ctx.getInt32Ty())
  } else {
    let is_unsigned = is_unsigned_kind(common.dataKind) ||
      common.dataKind is Ptr(_)
    let res = match (cmp, is_unsigned) {
      ("lt", true) => self.builder.createICmpULT(lval, rval)
      ("lt", false) => self.builder.createICmpSLT(lval, rval)
      ("gt", true) => self.builder.createICmpUGT(lval, rval)
      ("gt", false) => self.builder.createICmpSGT(lval, rval)
      ("le", true) => self.builder.createICmpULE(lval, rval)
      ("le", false) => self.builder.createICmpSLE(lval, rval)
      ("ge", true) => self.builder.createICmpUGE(lval, rval)
      ("ge", false) => self.builder.createICmpSGE(lval, rval)
      _ => codegen_unreachable()
    }
    self.builder.createZExt(res, self.llvm_ctx.getInt32Ty())
  }
}
