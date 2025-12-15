///|
fn Context::emit_shift_expr(
  self : Context,
  expr : @parser.ShiftExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation is incorrect.
  // first it does not handle floating point numbers correctly.
  // second, it does not handle Unsigned Right Shift correctly for signed integers.
  match expr.kind {
    AddiExpr(expr) => self.emit_additive_expr(expr)
    ShlExpr(left, right) => self.emit_shift(expr.ctype, left, right, true)
    ShrExpr(left, right) => self.emit_shift(expr.ctype, left, right, false)
  }
}

///|
fn Context::emit_shift(
  self : Context,
  result_ctype : @parser.CType,
  left : @parser.ShiftExpr,
  right : @parser.AddiExpr,
  is_left : Bool,
) -> &@IR.Value raise {
  let lraw = self.emit_shift_expr(left)
  let rraw = self.emit_additive_expr(right)
  let lval = self.cast_value_to_ctype(lraw, left.ctype, result_ctype)
  // shift amount is always treated as int type
  let rval = self.cast_value_to_ctype(rraw, right.ctype, @parser.CType::int())
  if is_left {
    self.builder.createShl(lval, rval)
  } else if is_unsigned_kind(result_ctype.dataKind) {
    self.builder.createLShr(lval, rval)
  } else {
    self.builder.createAShr(lval, rval)
  }
}
