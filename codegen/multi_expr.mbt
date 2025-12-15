///|
fn Context::emit_multiplicative_expr(
  self : Context,
  expr : @parser.MultiExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation didn't handle type promotion.
  // Besides, it didn't consider unsigned and floating point types.
  match expr.kind {
    CastExpr(expr) => self.emit_cast_expr(expr)
    MulExpr(left, right) => self.emit_mul_div_rem(expr.ctype, left, right, "*")
    DivExpr(left, right) => self.emit_mul_div_rem(expr.ctype, left, right, "/")
    ModExpr(left, right) => self.emit_mul_div_rem(expr.ctype, left, right, "%")
  }
}

///|
fn Context::emit_mul_div_rem(
  self : Context,
  result_ctype : @parser.CType,
  left : @parser.MultiExpr,
  right : @parser.CastExpr,
  op : String,
) -> &@IR.Value raise {
  let lraw = self.emit_multiplicative_expr(left)
  let rraw = self.emit_cast_expr(right)
  let lval = self.cast_value_to_ctype(lraw, left.ctype, result_ctype)
  let rval = self.cast_value_to_ctype(rraw, right.ctype, result_ctype)
  if is_floating_kind(result_ctype.dataKind) {
    match op {
      "*" => self.builder.createFMul(lval, rval)
      "/" => self.builder.createFDiv(lval, rval)
      "%" => self.builder.createFRem(lval, rval)
      _ => panic()
    }
  } else {
    let is_unsigned = is_unsigned_kind(result_ctype.dataKind)
    match op {
      "*" => self.builder.createMul(lval, rval)
      "/" =>
        if is_unsigned {
          self.builder.createUDiv(lval, rval)
        } else {
          self.builder.createSDiv(lval, rval)
        }
      "%" =>
        if is_unsigned {
          self.builder.createURem(lval, rval)
        } else {
          self.builder.createSRem(lval, rval)
        }
      _ => panic()
    }
  }
}
