///|
fn Context::emit_assign_expr(
  self : Context,
  assign_expr : @parser.AssignExpr,
) -> &@IR.Value raise {
  match assign_expr.kind {
    Conditional(cond_expr) => self.emit_conditional_expr(cond_expr)
    Assign(left, assign_op, right) =>
      self.emit_assignment(left, assign_op, right)
  }
}

///|
fn Context::emit_assignment(
  self : Context,
  left : @parser.UnaryExpr,
  assign_op : @parser.AssignOp,
  right : @parser.AssignExpr,
) -> &@IR.Value raise {
  fn try_get_lvalue_ptr_from_assign(
    self : Context,
    expr : @parser.AssignExpr,
  ) -> (&@IR.Value, @parser.CType)? {
    match expr.kind {
      Conditional(cond_expr) => {
        let unary = unwrap_unary_from_conditional(cond_expr) catch {
          _ => return None
        }
        let res = self.get_lvalue_ptr_from_unary(unary) catch { _ => return None }
        Some(res)
      }
      _ => None
    }
  }
  fn try_get_bitfield_access(
    self : Context,
    left : @parser.UnaryExpr,
  ) -> FieldAccess? raise {
    match left.kind {
      PostfixExpr(postfix_expr) =>
        match postfix_expr.kind {
          MemberAccess(base, field_name) => {
            let (base_ptr, base_ty) = self.get_lvalue_ptr_from_postfix(base)
            let acc = self.get_field_access(base_ptr, base_ty, field_name)
            if acc.bit_width is Some(_) { Some(acc) } else { None }
          }
          PtrMemberAccess(base, field_name) => {
            guard base.ctype.dataKind is Ptr(inner) else { return None }
            let base_ptr = self.emit_postfix_expr(base)
            let acc = self.get_field_access(base_ptr, inner, field_name)
            if acc.bit_width is Some(_) { Some(acc) } else { None }
          }
          _ => None
        }
      _ => None
    }
  }
  fn is_unsigned_bitfield(ty : @parser.CType) -> Bool {
    match ty.dataKind {
      Bool | UChar | UInt16 | UInt | ULong | ULongLong => true
      Enum(_, values) => {
        for item in values {
          let v = item.1
          if v < 0 {
            return false
          }
        }
        true
      }
      _ => false
    }
  }
  fn load_bitfield(
    self : Context,
    acc : FieldAccess,
  ) -> &@IR.Value raise {
    let container_ty = acc.container_ctype.unwrap()
    let llvm_cty = self.ctype_to_llvm_type(container_ty)
    let raw = self.load_value(acc.ptr, container_ty)
    let off = acc.bit_offset.unwrap()
    let w = acc.bit_width.unwrap()
    let shift = self.const_int_for_ctype(container_ty, off)
    let shifted = self.builder.createLShr(raw, shift)
    let mask_val = if w >= 64 { -1 } else { (1 << w) - 1 }
    let mask = self.const_int_for_ctype(container_ty, mask_val)
    let masked = self.builder.createAnd(shifted, mask)
    let val = if is_unsigned_bitfield(acc.ctype) {
      masked
    } else {
      let width = self.bitfield_container_bits(container_ty)
      let shl = self.const_int_for_ctype(container_ty, width - w)
      let tmp = self.builder.createShl(masked, shl)
      self.builder.createAShr(tmp, shl)
    }
    self.cast_value_to_ctype(val, container_ty, acc.ctype)
  }
  fn store_bitfield(
    self : Context,
    acc : FieldAccess,
    value : &@IR.Value,
    value_ctype : @parser.CType,
  ) -> &@IR.Value raise {
    let container_ty = acc.container_ctype.unwrap()
    let llvm_cty = self.ctype_to_llvm_type(container_ty)
    let old = self.load_value(acc.ptr, container_ty)
    let w = acc.bit_width.unwrap()
    let off = acc.bit_offset.unwrap()
    let mask_val = if w >= 64 { -1 } else { (1 << w) - 1 }
    let mask = self.const_int_for_ctype(container_ty, mask_val)
    let shift = self.const_int_for_ctype(container_ty, off)
    let field_mask = self.builder.createShl(mask, shift)
    let v0 = self.cast_value_to_ctype(value, value_ctype, acc.ctype)
    let v1 = self.cast_value_to_ctype(v0, acc.ctype, container_ty)
    let v2 = self.builder.createAnd(v1, mask)
    let vshift = self.builder.createShl(v2, shift)
    let cleared = self.builder.createAnd(old, self.builder.createNot(field_mask))
    let merged = self.builder.createOr(cleared, vshift)
    self.store_value(merged, acc.ptr, container_ty)
    v0
  }
  match try_get_bitfield_access(self, left) {
    Some(acc) => {
      let rhs_val = self.emit_assign_expr(right)
      let rhs_ctype = right.ctype
      let new_val = match assign_op {
        Assign => self.cast_value_to_ctype(rhs_val, rhs_ctype, acc.ctype)
        _ => {
          let lhs_val = load_bitfield(self, acc)
          let common = acc.ctype.common_type(rhs_ctype).unwrap_or(acc.ctype)
          let lcast = self.cast_value_to_ctype(lhs_val, acc.ctype, common)
          let rcast = self.cast_value_to_ctype(rhs_val, rhs_ctype, common)
          let calc = match assign_op {
            AddAssign => self.builder.createAdd(lcast, rcast)
            SubAssign => self.builder.createSub(lcast, rcast)
            MulAssign => self.builder.createMul(lcast, rcast)
            DivAssign => self.builder.createSDiv(lcast, rcast)
            ModAssign => self.builder.createSRem(lcast, rcast)
            ShlAssign => self.builder.createShl(lcast, rcast)
            ShrAssign => self.builder.createAShr(lcast, rcast)
            AndAssign => self.builder.createAnd(lcast, rcast)
            XorAssign => self.builder.createXor(lcast, rcast)
            OrAssign => self.builder.createOr(lcast, rcast)
            _ => lcast
          }
          self.cast_value_to_ctype(calc, common, acc.ctype)
        }
      }
      return store_bitfield(self, acc, new_val, acc.ctype)
    }
    None => ()
  }
  let (lhs_ptr, lhs_ctype) = self.get_lvalue_ptr_from_unary(left)
  if assign_op == Assign && is_aggregate_type(lhs_ctype) {
    match try_get_lvalue_ptr_from_assign(self, right) {
      Some((rhs_ptr, _)) => {
        self.store_aggregate_value(lhs_ptr, lhs_ctype, rhs_ptr)
        return self.load_value(lhs_ptr, lhs_ctype)
      }
      None => {
        let rhs_val = self.emit_assign_expr(right)
        let rhs_ctype = right.ctype
        let new_val = self.cast_value_to_ctype(rhs_val, rhs_ctype, lhs_ctype)
        self.store_aggregate_value(lhs_ptr, lhs_ctype, new_val)
        return new_val
      }
    }
  }
  let rhs_val = self.emit_assign_expr(right)
  let rhs_ctype = right.ctype
  let new_val = match assign_op {
    Assign => {
      match lhs_ctype.dataKind {
        Array(_, _) => {
          let tok = left.tokens[0]
          println(
            "Array assignment at \{tok.source_file}:\{tok.line} (\{tok.raw})",
          )
        }
        _ => ()
      }
      self.cast_value_to_ctype(rhs_val, rhs_ctype, lhs_ctype)
    }
    AddAssign =>
      self.compute_add_sub_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, true,
      )
    SubAssign =>
      self.compute_add_sub_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, false,
      )
    MulAssign =>
      self.compute_numeric_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, '*',
      )
    DivAssign =>
      self.compute_numeric_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, '/',
      )
    ModAssign =>
      self.compute_numeric_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, '%',
      )
    ShlAssign =>
      self.compute_shift_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, true,
      )
    ShrAssign =>
      self.compute_shift_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, false,
      )
    AndAssign =>
      self.compute_numeric_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, '&',
      )
    XorAssign =>
      self.compute_numeric_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, '^',
      )
    OrAssign =>
      self.compute_numeric_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, '|',
      )
  }
  self.store_value(new_val, lhs_ptr, lhs_ctype)
  new_val
}

///|
fn Context::load_lvalue(
  self : Context,
  ptr : &@IR.Value,
  ctype : @parser.CType,
) -> &@IR.Value raise {
  self.load_value(ptr, ctype)
}

///|
fn Context::compute_add_sub_assignment(
  self : Context,
  lhs_ptr : &@IR.Value,
  lhs_ctype : @parser.CType,
  rhs_val : &@IR.Value,
  rhs_ctype : @parser.CType,
  is_add : Bool,
) -> &@IR.Value raise {
  let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
  match lhs_ctype.dataKind {
    Ptr(elem_ty) => {
      let rhs_int = self.cast_value_to_ctype(
        rhs_val,
        rhs_ctype,
        @parser.CType::int(),
      )
      let step = if is_add {
        rhs_int
      } else {
        let zero = self.const_zero_value(rhs_int.getType())
        self.builder.createSub(zero, rhs_int)
      }
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(step)
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      (self.builder.createGEP(lhs_val, elem_llvm_ty, indices) : &@IR.Value)
    }
    _ => {
      let common = match lhs_ctype.common_type(rhs_ctype) {
        Some(t) => t
        None => {
          println(
            "Compiler ICE: parser allowed incompatible types '\{lhs_ctype}' and '\{rhs_ctype}' for '+=' or '-='",
          )
          panic()
        }
      }
      let lcast = self.cast_value_to_ctype(lhs_val, lhs_ctype, common)
      let rcast = self.cast_value_to_ctype(rhs_val, rhs_ctype, common)
      let sum = if is_floating_kind(common.dataKind) {
        if is_add {
          self.builder.createFAdd(lcast, rcast)
        } else {
          self.builder.createFSub(lcast, rcast)
        }
      } else if is_add {
        self.builder.createAdd(lcast, rcast)
      } else {
        self.builder.createSub(lcast, rcast)
      }
      self.cast_value_to_ctype(sum, common, lhs_ctype)
    }
  }
}

///|
fn Context::get_lvalue_ptr_from_unary(
  self : Context,
  expr : @parser.UnaryExpr,
) -> (&@IR.Value, @parser.CType) raise {
  match expr.kind {
    PostfixExpr(postfix_expr) => self.get_lvalue_ptr_from_postfix(postfix_expr)
    Deref(inner) => {
      // `*p` is an lvalue; evaluate inner to obtain the target pointer
      let ptr_val = self.emit_cast_expr(inner)
      (ptr_val, expr.ctype)
    }
    _ => raise SemanticError("Expression is not an assignable lvalue")
  }
}

///|
fn Context::get_lvalue_ptr_from_postfix(
  self : Context,
  expr : @parser.PostfixExpr,
) -> (&@IR.Value, @parser.CType) raise {
  match expr.kind {
    PrimExpr(prim_expr) =>
      match prim_expr.kind {
        Ident(name) =>
          match self.var_env.get(name) {
            Some(storage) => (storage, prim_expr.ctype)
            None => {
              match self.globals.get(name) {
                Some(gv) => {
                  let gptr : &@IR.Value = gv
                  let gty = self.global_types.get(name).unwrap_or(prim_expr.ctype)
                  (gptr, gty)
                }
                None => {
                  guard self.func_decls.get(name) is Some(_) else {
                    raise SemanticError("Undefined identifier '\{name}'")
                  }
                  let func = self.get_or_declare_function(name)
                  (func, prim_expr.ctype)
                }
              }
            }
          }
        CompoundLiteral(ty, init) => {
          let ptr = self.emit_compound_literal_ptr(ty, init)
          (ptr, ty)
        }
        Paren(inner) => self.get_lvalue_ptr_from_paren_expr(inner)
        _ => raise SemanticError("Primary expression is not assignable")
      }
    PostInc(_) | PostDec(_) =>
      raise SemanticError(
        "Cannot take the address of a post-increment expression",
      )
    FuncCall(_) =>
      raise SemanticError("Function call results are not assignable lvalues")
    ArrayAccess(arr_expr, idx_expr) => {
      let (ptr, elem_ty) = self.emit_array_access_ptr(arr_expr, idx_expr)
      (ptr, elem_ty)
    }
    MemberAccess(base, field_name) => {
      // lvalue 的 `p.x`：必须从内存里取 struct/union 的地址，再定位字段
      let (base_ptr, base_ty) = self.get_lvalue_ptr_from_postfix(base)
      let (field_ptr, fty) = self.get_field_ptr_and_type(
        base_ptr,
        base_ty,
        field_name,
      )
      (field_ptr, fty)
    }
    PtrMemberAccess(base, field_name) => {
      // lvalue 的 `p->x`：先取出 ptr 值，再 gep 到字段
      guard base.ctype.dataKind is Ptr(inner) else {
        raise SemanticError("Pointer member access on non-pointer type")
      }
      let base_ptr = self.emit_postfix_expr(base)
      let (field_ptr, fty) = self.get_field_ptr_and_type(
        base_ptr,
        inner,
        field_name,
      )
      (field_ptr, fty)
    }
  }
}

///|
fn Context::try_get_lvalue_ptr_from_postfix(
  self : Context,
  expr : @parser.PostfixExpr,
) -> (&@IR.Value, @parser.CType)? {
  let res = self.get_lvalue_ptr_from_postfix(expr) catch { _ => return None }
  Some(res)
}

///|
// For lvalues wrapped in parentheses, such as `(*p++)` in `(*p++)--`.
fn Context::get_lvalue_ptr_from_paren_expr(
  self : Context,
  expr : @parser.Expr,
) -> (&@IR.Value, @parser.CType) raise {
  // Only support the common lvalue case: a single, non-ternary, non-assignment expression
  // that ultimately is a UnaryExpr (e.g. Deref/Postfix/ArrayAccess/MemberAccess).
  guard expr.assign_exprs.length() == 1 else {
    raise SemanticError("Parenthesized expression is not an assignable lvalue")
  }
  let assign_expr = expr.assign_exprs[0]
  guard assign_expr.kind is Conditional(cond_expr) else {
    raise SemanticError("Parenthesized expression is not an assignable lvalue")
  }
  let unary = unwrap_unary_from_conditional(cond_expr) catch {
    _ =>
      raise SemanticError(
        "Parenthesized expression is not an assignable lvalue",
      )
  }
  self.get_lvalue_ptr_from_unary(unary)
}

///|
fn unwrap_unary_from_conditional(
  cond_expr : @parser.ConditionalExpr,
) -> @parser.UnaryExpr raise {
  // We only accept the "no-op wrapper" path down to UnaryExpr.
  guard cond_expr.kind is LogicalOrExpr(lor) else {
    raise SemanticError("not a plain expression")
  }
  guard lor.kind is LogicalAndExpr(land) else {
    raise SemanticError("not a plain expression")
  }
  guard land.kind is InclusiveOrExpr(ior) else {
    raise SemanticError("not a plain expression")
  }
  guard ior.kind is ExclusiveOrExpr(xor) else {
    raise SemanticError("not a plain expression")
  }
  guard xor.kind is AndExpr(ae) else {
    raise SemanticError("not a plain expression")
  }
  guard ae.kind is EqualityExpr(eq) else {
    raise SemanticError("not a plain expression")
  }
  guard eq.kind is RelationalExpr(rel) else {
    raise SemanticError("not a plain expression")
  }
  guard rel.kind is ShiftExpr(sh) else {
    raise SemanticError("not a plain expression")
  }
  guard sh.kind is AddiExpr(add) else {
    raise SemanticError("not a plain expression")
  }
  guard add.kind is MultiExpr(mul) else {
    raise SemanticError("not a plain expression")
  }
  guard mul.kind is CastExpr(cast) else {
    raise SemanticError("not a plain expression")
  }
  match cast.kind {
    UnaryExpr(u) => u
    _ => raise SemanticError("not a plain expression")
  }
}

///|
fn Context::apply_inc_dec(
  self : Context,
  lvalue_ptr : &@IR.Value,
  ctype : @parser.CType,
  is_inc~ : Bool,
) -> (&@IR.Value, &@IR.Value) raise {
  if !ctype.is_inc_ok() {
    let msg = "increment/decrement on unsupported type '\{ctype}'"
    codegen_unreachable(msg~)
  }
  let current_val = self.load_lvalue(lvalue_ptr, ctype)
  let updated_val = match ctype.dataKind {
    Ptr(elem_ty) => {
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let stepn = if is_inc { 1 } else { -1 }
      let step = self.llvm_ctx.getConstInt32(stepn)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(step)
      (self.builder.createGEP(current_val, elem_llvm_ty, indices) : &@IR.Value)
    }
    _others =>
      if is_floating_kind(ctype.dataKind) {
        let one = self.const_one_value(current_val.getType())
        if is_inc {
          self.builder.createFAdd(current_val, one)
        } else {
          self.builder.createFSub(current_val, one)
        }
      } else {
        let one = self.const_one_value(current_val.getType())
        if is_inc {
          self.builder.createAdd(current_val, one)
        } else {
          self.builder.createSub(current_val, one)
        }
      }
  }
  self.store_value(updated_val, lvalue_ptr, ctype)
  (current_val, updated_val)
}

///|
fn Context::compute_numeric_assignment(
  self : Context,
  lhs_ptr : &@IR.Value,
  lhs_ctype : @parser.CType,
  rhs_val : &@IR.Value,
  rhs_ctype : @parser.CType,
  op : Char,
) -> &@IR.Value raise {
  let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
  let common = match lhs_ctype.common_type(rhs_ctype) {
    Some(t) => t
    None => {
      let msg = "incompatible types '\{lhs_ctype}' and '\{rhs_ctype}' for op '\{op}='"
      codegen_unreachable(msg~)
    }
  }
  let lcast = self.cast_value_to_ctype(lhs_val, lhs_ctype, common)
  let rcast = self.cast_value_to_ctype(rhs_val, rhs_ctype, common)
  let res = if is_floating_kind(common.dataKind) {
    match op {
      '*' => self.builder.createFMul(lcast, rcast)
      '/' => self.builder.createFDiv(lcast, rcast)
      '%' => self.builder.createFRem(lcast, rcast)
      '&' | '|' | '^' => {
        let msg = "bitwise op on floating type '\{common}'"
        codegen_unreachable(msg~)
      }
      _ => codegen_unreachable()
    }
  } else {
    match op {
      '*' => self.builder.createMul(lcast, rcast)
      '/' if is_unsigned_kind(common.dataKind) =>
        self.builder.createUDiv(lcast, rcast)
      '/' => self.builder.createSDiv(lcast, rcast)
      '%' if is_unsigned_kind(common.dataKind) =>
        self.builder.createURem(lcast, rcast)
      '%' => self.builder.createSRem(lcast, rcast)
      '&' => self.builder.createAnd(lcast, rcast)
      '|' => self.builder.createOr(lcast, rcast)
      '^' => self.builder.createXor(lcast, rcast)
      _ => codegen_unreachable()
    }
  }
  self.cast_value_to_ctype(res, common, lhs_ctype)
}

///|
fn Context::compute_shift_assignment(
  self : Context,
  lhs_ptr : &@IR.Value,
  lhs_ctype : @parser.CType,
  rhs_val : &@IR.Value,
  rhs_ctype : @parser.CType,
  is_left : Bool,
) -> &@IR.Value raise {
  if !lhs_ctype.is_integral() {
    let msg = "shift assignment on non-integral type '\{lhs_ctype}'"
    codegen_unreachable(msg~)
  }
  let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
  let shift_amt_raw = self.cast_value_to_ctype(
    rhs_val,
    rhs_ctype,
    @parser.CType::int(),
  )
  let shift_amt = self.cast_value_to_ctype(
    shift_amt_raw,
    @parser.CType::int(),
    lhs_ctype,
  )
  let res = if is_left {
    self.builder.createShl(lhs_val, shift_amt)
  } else if is_unsigned_kind(lhs_ctype.dataKind) {
    self.builder.createLShr(lhs_val, shift_amt)
  } else {
    self.builder.createAShr(lhs_val, shift_amt)
  }
  self.cast_value_to_ctype(res, lhs_ctype, lhs_ctype)
}
