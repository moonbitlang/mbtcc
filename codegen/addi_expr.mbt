///|
pub fn Context::emit_additive_expr(
  self : Context,
  expr : @parser.AddiExpr,
) -> &@IR.Value raise {
  // TODO: This Implementation didn't handle type promotion.
  match expr.kind {
    MultiExpr(expr) => self.emit_multiplicative_expr(expr)
    AddExpr(left, right) => self.emit_add_sub(expr.ctype, left, right, true)
    SubExpr(left, right) => self.emit_add_sub(expr.ctype, left, right, false)
  }
}

///|
fn Context::emit_add_sub(
  self : Context,
  result_ctype : @parser.CType,
  left : @parser.AddiExpr,
  right : @parser.MultiExpr,
  is_add : Bool,
) -> &@IR.Value raise {
  match result_ctype.dataKind {
    Ptr(_) => {
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
          println(
            "Compiler ICE: parser produced pointer arithmetic with non-integral offset",
          )
          panic()
        }
      }
      let idx_val = self.cast_value_to_ctype(
        idx_val,
        if left.ctype.is_integral() {
          left.ctype
        } else {
          right.ctype
        },
        @parser.CType::int(),
      )
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
    _ => {
      let lval_raw = self.emit_additive_expr(left)
      let rval_raw = self.emit_multiplicative_expr(right)
      let lval = self.cast_value_to_ctype(lval_raw, left.ctype, result_ctype)
      let rval = self.cast_value_to_ctype(rval_raw, right.ctype, result_ctype)
      if is_floating_kind(result_ctype.dataKind) {
        if is_add {
          self.builder.createFAdd(lval, rval)
        } else {
          self.builder.createFSub(lval, rval)
        }
      } else if is_add {
        self.builder.createAdd(lval, rval)
      } else {
        self.builder.createSub(lval, rval)
      }
    }
  }
}
