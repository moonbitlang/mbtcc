///|
pub fn Context::emit_additive_expr(
  self : Context,
  expr : @parser.AddiExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation didn't handle type promotion.
  match expr.kind {
    MultiExpr(expr) => self.emit_multiplicative_expr(expr)
    AddExpr(left, right) =>
      self.emit_add_sub(expr.ctype, left, right, is_add=true)
    SubExpr(left, right) =>
      self.emit_add_sub(expr.ctype, left, right, is_add=false)
  }
}

///|
fn Context::emit_add_sub(
  self : Context,
  result_ctype : @parser.CType,
  left : @parser.AddiExpr,
  right : @parser.MultiExpr,
  is_add~ : Bool,
) -> &@IR.Value raise {
  if result_ctype.dataKind is Ptr(_) {
    return self.emit_add_sub_ptr(left, right, is_add~)
  }
  let lval_raw = self.emit_additive_expr(left)
  let rval_raw = self.emit_multiplicative_expr(right)
  let lval = self.cast_value_to_ctype(lval_raw, left.ctype, result_ctype)
  let rval = self.cast_value_to_ctype(rval_raw, right.ctype, result_ctype)
  match (is_add, is_floating_kind(result_ctype.dataKind)) {
    (true, true) => self.builder.createFAdd(lval, rval)
    (false, true) => self.builder.createFSub(lval, rval)
    (true, false) => self.builder.createAdd(lval, rval)
    (false, false) => self.builder.createSub(lval, rval)
  }
}

///|
fn Context::emit_add_sub_ptr(
  self : Self,
  left : @parser.AddiExpr,
  right : @parser.MultiExpr,
  is_add~ : Bool,
) -> &@IR.Value raise {
  // pointer +/- integer
  let (ptr_val, idx_val, elem_ty) = match
    (left.ctype.dataKind, right.ctype.dataKind) {
    (Ptr(elem), _) if right.ctype.is_integral() => {
      let base = self.emit_additive_expr(left)
      let idx_raw = self.emit_multiplicative_expr(right)
      (base, idx_raw, elem)
    }
    (_, Ptr(elem)) if left.ctype.is_integral() => {
      let base = self.emit_multiplicative_expr(right)
      let idx_raw = self.emit_additive_expr(left)
      (base, idx_raw, elem)
    }
    _ => {
      let msg = "parser produced pointer arithmetic with non-integral offset"
      codegen_unreachable(msg~)
    }
  }
  let from_ctype = match left.ctype.is_integral() {
    true => left.ctype
    false => right.ctype
  }
  let to_ctype = @parser.CType::int()
  let idx_val = self.cast_value_to_ctype(idx_val, from_ctype, to_ctype)
  let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
  let indices : Array[&@IR.Value] = Array::new()
  let step = if is_add {
    idx_val
  } else {
    let zero = self.llvm_ctx.getConstZero(idx_val.getType())
    self.builder.createSub(zero, idx_val)
  }
  indices.push(step)
  self.builder.createGEP(ptr_val, elem_llvm_ty, indices)
}
