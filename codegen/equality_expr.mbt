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
  let lraw = self.emit_equality_expr(left)
  let rraw = self.emit_relational_expr(right)
  let common = if left.ctype.dataKind is Ptr(_) &&
    right.ctype.dataKind is Ptr(_) {
    left.ctype
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
  match (is_floating, is_eq) {
    (true, true) => self.builder.createFCmpOEQ(lval, rval)
    (true, false) => self.builder.createFCmpONE(lval, rval)
    (false, true) => self.builder.createICmpEQ(lval, rval)
    (false, false) => self.builder.createICmpNE(lval, rval)
  }
}
