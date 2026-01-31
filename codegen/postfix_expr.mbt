///|
fn Context::emit_postfix_expr(
  self : Self,
  expr : @parser.PostfixExpr,
) -> &@IR.Value raise {
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
      // Prefer lvalue access for aggregates (supports anonymous fields + bitfields).
      match self.try_get_lvalue_ptr_from_postfix(expr) {
        Some((base_ptr, base_ty)) => {
          let acc = self.get_field_access(base_ptr, base_ty, member_name)
          match (acc.bit_width, acc.bit_offset) {
            (Some(w), Some(off)) => {
              let container_ty = acc.container_ctype.unwrap()
              let llvm_cty = self.ctype_to_llvm_type(container_ty)
              let raw = (self.builder.createLoad(llvm_cty, acc.ptr) : &@IR.Value)
              let shift = self.const_int_for_ctype(container_ty, off)
              let shifted = self.builder.createLShr(raw, shift)
              let mask_val = if w >= 64 { -1 } else { (1 << w) - 1 }
              let mask = self.const_int_for_ctype(container_ty, mask_val)
              let masked = self.builder.createAnd(shifted, mask)
              // Signed bitfield needs sign extension
              let is_unsigned = is_unsigned_bitfield(acc.ctype)
              let val = if is_unsigned {
                masked
              } else {
                let width = self.bitfield_container_bits(container_ty)
                let shl = self.const_int_for_ctype(container_ty, width - w)
                let tmp = self.builder.createShl(masked, shl)
                self.builder.createAShr(tmp, shl)
              }
              self.cast_value_to_ctype(val, container_ty, acc.ctype)
            }
            _ =>
              match acc.ctype.dataKind {
                Array(_, _) => {
                  let arr_llvm_ty = self.ctype_to_llvm_type(acc.ctype)
                  let zero = self.llvm_ctx.getConstInt32(0)
                  let arr_indices : Array[&@IR.Value] = Array::new()
                  arr_indices.push(zero)
                  arr_indices.push(zero)
                  (self.builder.createGEP(acc.ptr, arr_llvm_ty, arr_indices) : &@IR.Value)
                }
                _ => {
                  let llvm_ty = self.ctype_to_llvm_type(acc.ctype)
                  (self.builder.createLoad(llvm_ty, acc.ptr) : &@IR.Value)
                }
              }
          }
        }
        None => {
          // Fallback for rvalue structs: materialize into a temp for bitfields.
          let base_val = self.emit_postfix_expr(expr)
          let tmp = self.builder.createAlloca(self.ctype_to_llvm_type(expr.ctype))
          self.builder.createStore(base_val, tmp) |> ignore
          let acc = self.get_field_access(tmp, expr.ctype, member_name)
          match (acc.bit_width, acc.bit_offset) {
            (Some(w), Some(off)) => {
              let container_ty = acc.container_ctype.unwrap()
              let llvm_cty = self.ctype_to_llvm_type(container_ty)
              let raw = (self.builder.createLoad(llvm_cty, acc.ptr) : &@IR.Value)
              let shift = self.const_int_for_ctype(container_ty, off)
              let shifted = self.builder.createLShr(raw, shift)
              let mask_val = if w >= 64 { -1 } else { (1 << w) - 1 }
              let mask = self.const_int_for_ctype(container_ty, mask_val)
              let masked = self.builder.createAnd(shifted, mask)
              let is_unsigned = is_unsigned_bitfield(acc.ctype)
              let val = if is_unsigned {
                masked
              } else {
                let width = self.bitfield_container_bits(container_ty)
                let shl = self.const_int_for_ctype(container_ty, width - w)
                let tmp2 = self.builder.createShl(masked, shl)
                self.builder.createAShr(tmp2, shl)
              }
              self.cast_value_to_ctype(val, container_ty, acc.ctype)
            }
            _ =>
              match acc.ctype.dataKind {
                Array(_, _) => {
                  let arr_llvm_ty = self.ctype_to_llvm_type(acc.ctype)
                  let zero = self.llvm_ctx.getConstInt32(0)
                  let arr_indices : Array[&@IR.Value] = Array::new()
                  arr_indices.push(zero)
                  arr_indices.push(zero)
                  (self.builder.createGEP(acc.ptr, arr_llvm_ty, arr_indices) : &@IR.Value)
                }
                _ => {
                  let llvm_ty = self.ctype_to_llvm_type(acc.ctype)
                  (self.builder.createLoad(llvm_ty, acc.ptr) : &@IR.Value)
                }
              }
          }
        }
      }
    }
    PtrMemberAccess(expr, member_name) => {
      guard expr.ctype.dataKind is Ptr(inner) else {
        raise SemanticError("Pointer member access on non-pointer type")
      }
      let base_ptr = self.emit_postfix_expr(expr)
      let acc = self.get_field_access(base_ptr, inner, member_name)
      match (acc.bit_width, acc.bit_offset) {
        (Some(w), Some(off)) => {
          let container_ty = acc.container_ctype.unwrap()
          let llvm_cty = self.ctype_to_llvm_type(container_ty)
          let raw = (self.builder.createLoad(llvm_cty, acc.ptr) : &@IR.Value)
          let shift = self.const_int_for_ctype(container_ty, off)
          let shifted = self.builder.createLShr(raw, shift)
          let mask_val = if w >= 64 { -1 } else { (1 << w) - 1 }
          let mask = self.const_int_for_ctype(container_ty, mask_val)
          let masked = self.builder.createAnd(shifted, mask)
          let is_unsigned = is_unsigned_bitfield(acc.ctype)
          let val = if is_unsigned {
            masked
          } else {
            let width = self.bitfield_container_bits(container_ty)
            let shl = self.const_int_for_ctype(container_ty, width - w)
            let tmp2 = self.builder.createShl(masked, shl)
            self.builder.createAShr(tmp2, shl)
          }
          self.cast_value_to_ctype(val, container_ty, acc.ctype)
        }
        _ =>
          match acc.ctype.dataKind {
            Array(_, _) => {
              let arr_llvm_ty = self.ctype_to_llvm_type(acc.ctype)
              let zero = self.llvm_ctx.getConstInt32(0)
              let arr_indices : Array[&@IR.Value] = Array::new()
              arr_indices.push(zero)
              arr_indices.push(zero)
              (self.builder.createGEP(acc.ptr, arr_llvm_ty, arr_indices) : &@IR.Value)
            }
            _ =>
              (self.builder.createLoad(self.ctype_to_llvm_type(acc.ctype), acc.ptr) : &@IR.Value)
          }
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
  fn get_sync_ptr_and_elem(
    self : Context,
    arg0 : @parser.AssignExpr,
  ) -> (&@IR.Value, @parser.CType) raise {
    let ptr_val = self.emit_assign_expr(arg0)
    let elem_ty = match arg0.ctype.dataKind {
      Ptr(t) => t
      Array(t, _) => t
      _ => raise SemanticError("Atomic builtin requires pointer argument")
    }
    (ptr_val, elem_ty)
  }
  match func_expr.kind {
    PrimExpr({ kind: Ident(name), .. }) if name == "__sync_fetch_and_add" ||
        name == "__sync_fetch_and_sub" => {
        guard arg_exprs.length() == 2 else {
          raise SemanticError("\{name} requires exactly two arguments")
        }
        let (mem_ptr, elem_ty) = get_sync_ptr_and_elem(self, arg_exprs[0])
        let val_raw = self.emit_assign_expr(arg_exprs[1])
        let val =
          self.cast_value_to_ctype(val_raw, arg_exprs[1].ctype, elem_ty)
        let llvm_ty = self.ctype_to_llvm_type(elem_ty)
        let old = (self.builder.createLoad(llvm_ty, mem_ptr) : &@IR.Value)
        let new_val = if name == "__sync_fetch_and_add" {
          self.builder.createAdd(old, val)
        } else {
          self.builder.createSub(old, val)
        }
        let _ = self.builder.createStore(new_val, mem_ptr)
        return old
      }
    PrimExpr({ kind: Ident(name), .. }) if name == "__sync_add_and_fetch" => {
      guard arg_exprs.length() == 2 else {
        raise SemanticError("__sync_add_and_fetch requires exactly two arguments")
      }
      let (mem_ptr, elem_ty) = get_sync_ptr_and_elem(self, arg_exprs[0])
      let val_raw = self.emit_assign_expr(arg_exprs[1])
      let val =
        self.cast_value_to_ctype(val_raw, arg_exprs[1].ctype, elem_ty)
      let llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let old = (self.builder.createLoad(llvm_ty, mem_ptr) : &@IR.Value)
      let new_val = self.builder.createAdd(old, val)
      let _ = self.builder.createStore(new_val, mem_ptr)
      return new_val
    }
    PrimExpr({ kind: Ident(name), .. }) if name == "__sync_lock_test_and_set" => {
      guard arg_exprs.length() == 2 else {
        raise SemanticError("__sync_lock_test_and_set requires exactly two arguments")
      }
      let (mem_ptr, elem_ty) = get_sync_ptr_and_elem(self, arg_exprs[0])
      let val_raw = self.emit_assign_expr(arg_exprs[1])
      let val =
        self.cast_value_to_ctype(val_raw, arg_exprs[1].ctype, elem_ty)
      let llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let old = (self.builder.createLoad(llvm_ty, mem_ptr) : &@IR.Value)
      let _ = self.builder.createStore(val, mem_ptr)
      return old
    }
    PrimExpr({ kind: Ident(name), .. }) if name == "__sync_val_compare_and_swap" => {
        guard arg_exprs.length() == 3 else {
          raise SemanticError("__sync_val_compare_and_swap requires three arguments")
        }
        let (mem_ptr, elem_ty) = get_sync_ptr_and_elem(self, arg_exprs[0])
        let expect_raw = self.emit_assign_expr(arg_exprs[1])
        let desired_raw = self.emit_assign_expr(arg_exprs[2])
        let expect =
          self.cast_value_to_ctype(expect_raw, arg_exprs[1].ctype, elem_ty)
        let desired =
          self.cast_value_to_ctype(desired_raw, arg_exprs[2].ctype, elem_ty)
        let llvm_ty = self.ctype_to_llvm_type(elem_ty)
        let old = (self.builder.createLoad(llvm_ty, mem_ptr) : &@IR.Value)
        let cmp = self.builder.createICmpEQ(old, expect)
        let next = self.builder.createSelect(cmp, desired, old)
        let _ = self.builder.createStore(next, mem_ptr)
        return old
      }
    PrimExpr({ kind: Ident(name), .. }) if name == "alloca" || name == "__builtin_alloca" => {
      guard arg_exprs.length() == 1 else {
        raise SemanticError("alloca requires exactly one argument")
      }
      let size_expr = arg_exprs[0]
      let size_val = self.emit_assign_expr(size_expr)
      let size_cast = self.cast_value_to_ctype(
        size_val,
        size_expr.ctype,
        @parser.CType::ulong(),
      )
      let i8_ty = self.llvm_ctx.getInt8Ty()
      return (self.builder.createArrayAlloca(i8_ty, size_cast) : &@IR.Value)
    }
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
      let fname = "llvm.va_start"
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
      let fname = "llvm.va_end"
      let func = match self.llvm_mod.getFunction(fname) {
        Some(f) => f
        None => self.llvm_mod.addFunction(fty, fname)
      }
      let args : Array[&@IR.Value] = [ap_ptr]
      return (self.builder.createCall(func, args) : &@IR.Value)
    }
    PrimExpr({ kind: Ident(name), .. }) if name == "__builtin_va_copy" => {
      guard arg_exprs.length() >= 2 else {
        raise SemanticError("__builtin_va_copy requires two arguments")
      }
      let dst_ptr = get_va_list_ptr(self, arg_exprs[0])
      let src_ptr = get_va_list_ptr(self, arg_exprs[1])
      let ptr_ty = self.llvm_ctx.getPtrTy()
      let src_val = self.builder.createLoad(ptr_ty, src_ptr)
      self.builder.createStore(src_val, dst_ptr) |> ignore
      return self.llvm_ctx.getConstInt32(0)
    }
    PrimExpr({ kind: Ident(name), .. }) if name == "__builtin_clzll" => {
      guard arg_exprs.length() >= 1 else {
        raise SemanticError("__builtin_clzll requires one argument")
      }
      let arg_expr = arg_exprs[0]
      let raw = self.emit_assign_expr(arg_expr)
      let arg64 = self.cast_value_to_ctype(
        raw,
        arg_expr.ctype,
        @parser.CType::ulonglong(),
      )
      let i64_ty = self.llvm_ctx.getInt64Ty()
      let i1_ty = self.llvm_ctx.getInt1Ty()
      let fty = self.llvm_ctx.getFunctionType(
        i64_ty,
        [i64_ty, i1_ty],
        isVarArg=false,
      )
      let fname = "llvm.ctlz.i64"
      let func = match self.llvm_mod.getFunction(fname) {
        Some(f) => f
        None => self.llvm_mod.addFunction(fty, fname)
      }
      let args : Array[&@IR.Value] = Array::new()
      args.push(arg64)
      args.push(self.llvm_ctx.getConstFalse())
      let res = (self.builder.createCall(func, args) : &@IR.Value)
      return self.cast_value_to_ctype(
        res,
        @parser.CType::ulonglong(),
        @parser.CType::int(),
      )
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
