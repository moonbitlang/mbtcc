///|
fn Context::emit_postfix_expr(
  self : Self,
  expr : @parser.PostfixExpr,
) -> &@IR.Value raise {
  match expr.kind {
    PrimExpr(expr) => self.emit_prim_expr(expr)
    ArrayAccess(expr, idx_expr) => {
      let (elem_ptr, elem_ty) = self.emit_array_access_ptr(expr, idx_expr)
      match elem_ty.dataKind {
        Array(_, _) => {
          let arr_llvm_ty = self.ctype_to_llvm_type(elem_ty)
          let zero = self.llvm_ctx.getConstInt32(0)
          let indices : Array[&@IR.Value] = Array::new()
          indices.push(zero)
          indices.push(zero)
          (self.builder.createGEP(elem_ptr, arr_llvm_ty, indices) : &@IR.Value)
        }
        _ => {
          let llvm_ty = self.ctype_to_llvm_type(elem_ty)
          (self.builder.createLoad(llvm_ty, elem_ptr) : &@IR.Value)
        }
      }
    }
    FuncCall(func_expr, arg_exprs) => self.emit_func_call(func_expr, arg_exprs)
    MemberAccess(expr, member_name) => {
      // Prefer lvalue access for aggregates (supports anonymous fields).
      match self.try_get_lvalue_ptr_from_postfix(expr) {
        Some((base_ptr, base_ty)) => {
          let (field_ptr, fty) = self.get_field_ptr_and_type(
            base_ptr,
            base_ty,
            member_name,
          )
          match fty.dataKind {
            Array(_, _) => {
              let arr_llvm_ty = self.ctype_to_llvm_type(fty)
              let zero = self.llvm_ctx.getConstInt32(0)
              let arr_indices : Array[&@IR.Value] = Array::new()
              arr_indices.push(zero)
              arr_indices.push(zero)
              (self.builder.createGEP(field_ptr, arr_llvm_ty, arr_indices) : &@IR.Value)
            }
            _ => {
              let llvm_ty = self.ctype_to_llvm_type(fty)
              (self.builder.createLoad(llvm_ty, field_ptr) : &@IR.Value)
            }
          }
        }
        None => {
          // Fallback for rvalue structs: use extractvalue for direct struct fields.
          let (idx, fty) = struct_field_index_and_type(expr.ctype, member_name)
          match fty.dataKind {
            Array(_, _) => {
              let base_val = self.emit_postfix_expr(expr)
              let st_llvm_ty = self.ctype_to_llvm_type(expr.ctype)
              let zero = self.llvm_ctx.getConstInt32(0)
              let indices : Array[&@IR.Value] = Array::new()
              indices.push(zero)
              indices.push(self.llvm_ctx.getConstInt32(idx))
              let field_ptr = self.builder.createGEP(base_val, st_llvm_ty, indices)
              let arr_llvm_ty = self.ctype_to_llvm_type(fty)
              let arr_indices : Array[&@IR.Value] = Array::new()
              arr_indices.push(zero)
              arr_indices.push(zero)
              (self.builder.createGEP(field_ptr, arr_llvm_ty, arr_indices) : &@IR.Value)
            }
            _ => self.builder.createExtractValue(self.emit_postfix_expr(expr), idx)
          }
        }
      }
    }
    PtrMemberAccess(expr, member_name) => {
      guard expr.ctype.dataKind is Ptr(inner) else {
        raise SemanticError("Pointer member access on non-pointer type")
      }
      let base_ptr = self.emit_postfix_expr(expr)
      let (field_ptr, fty) = self.get_field_ptr_and_type(
        base_ptr,
        inner,
        member_name,
      )
      match fty.dataKind {
        Array(_, _) => {
          let arr_llvm_ty = self.ctype_to_llvm_type(fty)
          let zero = self.llvm_ctx.getConstInt32(0)
          let arr_indices : Array[&@IR.Value] = Array::new()
          arr_indices.push(zero)
          arr_indices.push(zero)
          (self.builder.createGEP(field_ptr, arr_llvm_ty, arr_indices) : &@IR.Value)
        }
        _ =>
          (self.builder.createLoad(self.ctype_to_llvm_type(fty), field_ptr) : &@IR.Value)
      }
    }
    PostInc(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_postfix(expr)
      let (old_val, _) = self.apply_inc_dec(ptr, ctype, is_inc=true)
      old_val
    }
    PostDec(expr) => {
      let (ptr, ctype) = self.get_lvalue_ptr_from_postfix(expr)
      let (old_val, _) = self.apply_inc_dec(ptr, ctype, is_inc=false)
      old_val
    }
  }
}

///|
fn Context::emit_func_call(
  self : Self,
  func_expr : @parser.PostfixExpr,
  arg_exprs : Array[@parser.AssignExpr],
) -> &@IR.Value raise {
  fn extract_unary_from_assign_expr(
    expr : @parser.AssignExpr,
  ) -> @parser.UnaryExpr? {
    match expr.kind {
      Conditional(cond) =>
        match cond.kind {
          LogicalOrExpr(or_expr) =>
            match or_expr.kind {
              LogicalAndExpr(and_expr) =>
                match and_expr.kind {
                  InclusiveOrExpr(ior_expr) =>
                    match ior_expr.kind {
                      ExclusiveOrExpr(xor_expr) =>
                        match xor_expr.kind {
                          AndExpr(and2_expr) =>
                            match and2_expr.kind {
                              EqualityExpr(eq_expr) =>
                                match eq_expr.kind {
                                  RelationalExpr(rel_expr) =>
                                    match rel_expr.kind {
                                      ShiftExpr(shift_expr) =>
                                        match shift_expr.kind {
                                          AddiExpr(add_expr) =>
                                            match add_expr.kind {
                                              MultiExpr(mul_expr) =>
                                                match mul_expr.kind {
                                                  CastExpr(cast_expr) =>
                                                    match cast_expr.kind {
                                                      UnaryExpr(unary_expr) =>
                                                        Some(unary_expr)
                                                      _ => None
                                                    }
                                                  _ => None
                                                }
                                              _ => None
                                            }
                                          _ => None
                                        }
                                      _ => None
                                    }
                                  _ => None
                                }
                              _ => None
                            }
                          _ => None
                        }
                      _ => None
                    }
                  _ => None
                }
              _ => None
            }
          _ => None
        }
      _ => None
    }
  }
  fn get_va_list_ptr(
    self : Context,
    arg0 : @parser.AssignExpr,
  ) -> &@IR.Value raise {
    let unary = match extract_unary_from_assign_expr(arg0) {
      Some(u) => u
      None => raise SemanticError("va_list argument must be an lvalue")
    }
    let (ptr, _) = self.get_lvalue_ptr_from_unary(unary)
    ptr
  }
  fn coerce_vararg_aggregate(
    self : Context,
    val : &@IR.Value,
    ty : @parser.CType,
  ) -> &@IR.Value raise {
    let size = self.ctype_sizeof_bytes(ty)
    let slots = ((size + 7) / 8).to_int()
    let i64_ty = self.llvm_ctx.getInt64Ty()
    let coerce_ty = if slots == 1 {
      (i64_ty : &@IR.Type)
    } else {
      (self.llvm_ctx.getArrayType(i64_ty, slots) : &@IR.Type)
    }
    let tmp = self.builder.createAlloca(self.ctype_to_llvm_type(ty))
    match val.getType().asTypeEnum() {
      PointerType(_) => self.store_aggregate_value(tmp, ty, val)
      _ => self.builder.createStore(val, tmp) |> ignore
    }
    let tmp_ptr = self.builder.createBitCast(tmp, self.llvm_ctx.getPtrTy())
    (self.builder.createLoad(coerce_ty, tmp_ptr) : &@IR.Value)
  }
  match func_expr.kind {
    PrimExpr({ kind: Ident(name), .. }) if name == "__builtin_va_start" => {
      guard arg_exprs.length() >= 1 else {
        raise SemanticError("__builtin_va_start requires at least one argument")
      }
      let ap_ptr = get_va_list_ptr(self, arg_exprs[0])
      if arg_exprs.length() >= 2 {
        // Evaluate last argument for side effects
        self.emit_assign_expr(arg_exprs[1]) |> ignore
      }
      let void_ty = self.llvm_ctx.getVoidTy()
      let ptr_ty = self.llvm_ctx.getPtrTy()
      let fty = self.llvm_ctx.getFunctionType(void_ty, [ptr_ty], isVarArg=false)
      let fname = "llvm.va_start.p0"
      let func = match self.llvm_mod.getFunction(fname) {
        Some(f) => f
        None => self.llvm_mod.addFunction(fty, fname)
      }
      let args : Array[&@IR.Value] = [ap_ptr]
      return (self.builder.createCall(func, args) : &@IR.Value)
    }
    PrimExpr({ kind: Ident(name), .. }) if name == "__builtin_va_end" => {
      guard arg_exprs.length() >= 1 else {
        raise SemanticError("__builtin_va_end requires at least one argument")
      }
      let ap_ptr = get_va_list_ptr(self, arg_exprs[0])
      let void_ty = self.llvm_ctx.getVoidTy()
      let ptr_ty = self.llvm_ctx.getPtrTy()
      let fty = self.llvm_ctx.getFunctionType(void_ty, [ptr_ty], isVarArg=false)
      let fname = "llvm.va_end.p0"
      let func = match self.llvm_mod.getFunction(fname) {
        Some(f) => f
        None => self.llvm_mod.addFunction(fty, fname)
      }
      let args : Array[&@IR.Value] = [ap_ptr]
      return (self.builder.createCall(func, args) : &@IR.Value)
    }
    _ => ()
  }
  let func_value = self.emit_postfix_expr(func_expr)
  // The function value should be a Function
  // TODO: Handle function pointers later
  match func_value.asValueEnum() {
    Function(func) => {
      let args : Array[&@IR.Value] = Array::new()
      let decl = self.func_decls.get(func.getName())
      let (params, is_variadic) = match decl {
        Some({ dataKind: Function(params, _, is_variadic~), .. }) =>
          (params, is_variadic)
        _ => (Array::new(), false)
      }
      let fixed_n = params.length()
      for i in 0..<arg_exprs.length() {
        let arg_expr = arg_exprs[i]
        let raw = self.emit_assign_expr(arg_expr)
        let casted = if i < fixed_n {
          let (param_ty, _) = params[i]
          self.cast_value_to_ctype(raw, arg_expr.ctype, param_ty)
        } else if is_variadic {
          if arg_expr.ctype.dataKind is Array(_, _) {
            raw
          } else if is_aggregate_type(arg_expr.ctype) {
            coerce_vararg_aggregate(self, raw, arg_expr.ctype)
          } else {
            match arg_expr.ctype.dataKind {
              Char | UChar | Int16 | UInt16 =>
                self.cast_value_to_ctype(
                  raw,
                  arg_expr.ctype,
                  @parser.CType::int(),
                )
              Float =>
                self.cast_value_to_ctype(
                  raw,
                  arg_expr.ctype,
                  @parser.CType::double(),
                )
              _ => raw
            }
          }
        } else {
          raw
        }
        args.push(casted)
      }
      self.builder.createCall(func, args)
    }
    _ => {
      let (param_tys, ret_ty, is_variadic) = match func_expr.ctype.dataKind {
        Function(params, ret_ty, is_variadic~) => (params, ret_ty, is_variadic)
        Ptr({ dataKind: Function(params, ret_ty, is_variadic~), .. }) =>
          (params, ret_ty, is_variadic)
        _ => raise SemanticError("Function call target is not a function")
      }
      let llvm_param_tys : Array[&@IR.Type] = Array::new()
      for p in param_tys {
        let (pty, _) = p
        llvm_param_tys.push(self.ctype_to_llvm_type(pty))
      }
      let llvm_ret_ty = self.ctype_to_llvm_type(ret_ty)
      let fty = self.llvm_ctx.getFunctionType(
        llvm_ret_ty,
        llvm_param_tys,
        isVarArg=is_variadic,
      )
      let args : Array[&@IR.Value] = Array::new()
      let fixed_n = param_tys.length()
      for i in 0..<arg_exprs.length() {
        let arg_expr = arg_exprs[i]
        let raw = self.emit_assign_expr(arg_expr)
        let casted = if i < fixed_n {
          let (pty, _) = param_tys[i]
          self.cast_value_to_ctype(raw, arg_expr.ctype, pty)
        } else if is_variadic {
          if arg_expr.ctype.dataKind is Array(_, _) {
            raw
          } else if is_aggregate_type(arg_expr.ctype) {
            coerce_vararg_aggregate(self, raw, arg_expr.ctype)
          } else {
            match arg_expr.ctype.dataKind {
              Char | UChar | Int16 | UInt16 =>
                self.cast_value_to_ctype(
                  raw,
                  arg_expr.ctype,
                  @parser.CType::int(),
                )
              Float =>
                self.cast_value_to_ctype(
                  raw,
                  arg_expr.ctype,
                  @parser.CType::double(),
                )
              _ => raw
            }
          }
        } else {
          raw
        }
        args.push(casted)
      }
      self.builder.createCallPtr(func_value, fty, args)
    }
  }
}
