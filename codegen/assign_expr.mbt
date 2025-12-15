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
    Assign => self.ensure_assignable_value(rhs_val, rhs_ctype, lhs_ctype)
    AddAssign =>
      self.compute_add_sub_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, true,
      )
    SubAssign =>
      self.compute_add_sub_assignment(
        lhs_ptr, lhs_ctype, rhs_val, rhs_ctype, false,
      )
    MulAssign => {
      self.ensure_numeric(
        lhs_ctype, "Operator '*=' requires a numeric left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createMul(lhs_val, rhs_val)
    }
    DivAssign => {
      self.ensure_numeric(
        lhs_ctype, "Operator '/=' requires a numeric left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createSDiv(lhs_val, rhs_val)
    }
    ModAssign => {
      self.ensure_integral(
        lhs_ctype, "Operator '%=' requires an integral left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createSRem(lhs_val, rhs_val)
    }
    ShlAssign => {
      self.ensure_integral(
        lhs_ctype, "Operator '<<=' requires an integral left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createShl(lhs_val, rhs_val)
    }
    ShrAssign => {
      self.ensure_integral(
        lhs_ctype, "Operator '>>=' requires an integral left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createLShr(lhs_val, rhs_val)
    }
    AndAssign => {
      self.ensure_integral(
        lhs_ctype, "Operator '&=' requires an integral left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createAnd(lhs_val, rhs_val)
    }
    XorAssign => {
      self.ensure_integral(
        lhs_ctype, "Operator '^=' requires an integral left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createXor(lhs_val, rhs_val)
    }
    OrAssign => {
      self.ensure_integral(
        lhs_ctype, "Operator '|=' requires an integral left value",
      )
      let lhs_val = self.load_lvalue(lhs_ptr, lhs_ctype)
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      self.builder.createOr(lhs_val, rhs_val)
    }
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
      if !rhs_ctype.is_integral() {
        println(
          "Compiler ICE: parser allowed non-integral offset '\{rhs_ctype}' in pointer arithmetic",
        )
        panic()
      }
      let step = if is_add {
        rhs_val
      } else {
        let zero = self.llvm_ctx.getConstZero(rhs_val.getType())
        self.builder.createSub(zero, rhs_val)
      }
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(step)
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      self.builder.createGEP(lhs_val, elem_llvm_ty, indices)
    }
    _ => {
      self.ensure_same_ctype(lhs_ctype, rhs_ctype)
      if is_add {
        self.builder.createAdd(lhs_val, rhs_val)
      } else {
        self.builder.createSub(lhs_val, rhs_val)
      }
    }
  }
}

///|
fn Context::ensure_assignable_value(
  self : Context,
  rhs_val : &@IR.Value,
  rhs_ctype : @parser.CType,
  expected_ctype : @parser.CType,
) -> &@IR.Value {
  self.ensure_same_ctype(expected_ctype, rhs_ctype)
  rhs_val
}

///|
fn Context::ensure_same_ctype(
  self : Context,
  expected_ctype : @parser.CType,
  actual_ctype : @parser.CType,
) -> Unit {
  ignore(self)
  if expected_ctype != actual_ctype {
    println(
      "Compiler ICE: type mismatch between parser result '\{expected_ctype}' and value '\{actual_ctype}'",
    )
    panic()
  }
}

///|
fn Context::ensure_numeric(
  self : Context,
  ctype : @parser.CType,
  msg : String,
) -> Unit {
  ignore(self)
  if !ctype.is_numeric() {
    println("Compiler ICE: \{msg}")
    panic()
  }
}

///|
fn Context::ensure_integral(
  self : Context,
  ctype : @parser.CType,
  msg : String,
) -> Unit {
  ignore(self)
  if !ctype.is_integral() {
    println("Compiler ICE: \{msg}")
    panic()
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
      let ptr_val = self.emit_unary_expr(inner)
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
        _ => raise SemanticError("Primary expression is not assignable")
      }
    PostInc(_) | PostDec(_) =>
      raise SemanticError(
        "Cannot take the address of a post-increment expression",
      )
    FuncCall(_) =>
      raise SemanticError("Function call results are not assignable lvalues")
    ArrayAccess(_, _) =>
      raise Unimplemented(
        "Array access codegen for lvalues is not implemented yet",
      )
    MemberAccess(_, _) =>
      raise Unimplemented(
        "Member access codegen for lvalues is not implemented yet",
      )
    PtrMemberAccess(_, _) =>
      raise Unimplemented(
        "Pointer member access codegen for lvalues is not implemented yet",
      )
  }
}

///|
fn Context::apply_inc_dec(
  self : Context,
  lvalue_ptr : &@IR.Value,
  ctype : @parser.CType,
  is_inc : Bool,
) -> (&@IR.Value, &@IR.Value) raise {
  if !ctype.is_inc_ok() {
    println(
      "Compiler ICE: parser allowed inc/dec on unsupported type '\{ctype}'",
    )
    panic()
  }
  let current_val = self.load_lvalue(lvalue_ptr, ctype)
  let updated_val = match ctype.dataKind {
    Ptr(elem_ty) => {
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let step = self.llvm_ctx.getConstInt32(if is_inc { 1 } else { -1 })
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(step)
      self.builder.createGEP(current_val, elem_llvm_ty, indices)
    }
    _ => {
      let one = self.llvm_ctx.getConstOne(current_val.getType())
      if is_inc {
        self.builder.createAdd(current_val, one)
      } else {
        self.builder.createSub(current_val, one)
      }
    }
  }
  self.builder.createStore(updated_val, lvalue_ptr) |> ignore
  (current_val, updated_val)
}
