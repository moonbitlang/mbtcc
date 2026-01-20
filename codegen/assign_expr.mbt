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
  let (lhs_ptr, lhs_ctype) = self.get_lvalue_ptr_from_unary(left)
  let rhs_val = self.emit_assign_expr(right)
  let rhs_ctype = right.ctype
  let new_val = match assign_op {
    Assign => self.cast_value_to_ctype(rhs_val, rhs_ctype, lhs_ctype)
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
  self.builder.createStore(new_val, lhs_ptr) |> ignore
  new_val
}

///|
fn Context::load_lvalue(
  self : Context,
  ptr : &@IR.Value,
  ctype : @parser.CType,
) -> &@IR.Value raise {
  let llvm_ty = self.ctype_to_llvm_type(ctype)
  self.builder.createLoad(llvm_ty, ptr)
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
        let zero = self.llvm_ctx.getConstZero(rhs_int.getType())
        self.builder.createSub(zero, rhs_int)
      }
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(step)
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      self.builder.createGEP(lhs_val, elem_llvm_ty, indices)
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
        Ident(name) => {
          guard self.var_env.get(name) is Some(storage) else {
            raise SemanticError("Undefined identifier '\{name}'")
          }
          (storage, prim_expr.ctype)
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
      // lvalue 的 `p.x`：必须从内存里取 struct 的地址，再 gep 到字段
      let (base_ptr, base_ty) = self.get_lvalue_ptr_from_postfix(base)
      let (idx, fty) = struct_field_index_and_type(base_ty, field_name)
      let st_llvm_ty = self.ctype_to_llvm_type(base_ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(self.llvm_ctx.getConstInt32(idx))
      let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
      (field_ptr, fty)
    }
    PtrMemberAccess(base, field_name) => {
      // lvalue 的 `p->x`：先取出 ptr 值，再 gep 到字段
      guard base.ctype.dataKind is Ptr(inner) else {
        raise SemanticError("Pointer member access on non-pointer type")
      }
      let (idx, fty) = struct_field_index_and_type(inner, field_name)
      let base_ptr = self.emit_postfix_expr(base)
      let st_llvm_ty = self.ctype_to_llvm_type(inner)
      let zero = self.llvm_ctx.getConstInt32(0)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(self.llvm_ctx.getConstInt32(idx))
      let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
      (field_ptr, fty)
    }
  }
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
      self.builder.createGEP(current_val, elem_llvm_ty, indices)
    }
    _others => {
      let one = self.llvm_ctx.getConstOne(current_val.getType())
      if is_inc {
        self.builder.createAdd(current_val, one)
      } else {
        self.builder.createSub(current_val, one)
      }
    }
  }
  let _ = self.builder.createStore(updated_val, lvalue_ptr)
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
  let shift_amt = self.cast_value_to_ctype(
    rhs_val,
    rhs_ctype,
    @parser.CType::int(),
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
