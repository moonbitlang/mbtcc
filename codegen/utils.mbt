///|
#callsite(autofill(loc))
fn[T] codegen_unreachable(loc~ : SourceLoc, msg? : String = "") -> T {
  println("Compiler ICE: reached unreachable code: \{loc}")
  if !msg.is_empty() {
    println("  - \{msg}")
  }
  panic()
}

///|
/// Compute `arr[idx]` element address (for both lvalue and rvalue load)
fn Context::emit_array_access_ptr(
  self : Context,
  arr_expr : @parser.PostfixExpr,
  idx_expr : @parser.Expr,
) -> (&@IR.Value, @parser.CType) raise {
  let idx_raw = self.emit_expr(idx_expr)
  let idx_i32 = self.cast_value_to_ctype(
    idx_raw,
    idx_expr.ctype,
    @parser.CType::int(),
  )
  match arr_expr.ctype.dataKind {
    Ptr(elem_ty) => {
      let base_ptr = self.emit_postfix_expr(arr_expr)
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(idx_i32)
      let elem_ptr = self.builder.createGEP(base_ptr, elem_llvm_ty, indices)
      (elem_ptr, elem_ty)
    }
    Array(elem_ty, _) => {
      let (base_ptr, _) = self.get_lvalue_ptr_from_postfix(arr_expr)
      let arr_llvm_ty = self.ctype_to_llvm_type(arr_expr.ctype)
      let zero = self.llvm_ctx.getConstInt32(0)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(idx_i32)
      let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
      (elem_ptr, elem_ty)
    }
    _ =>
      raise SemanticError("Array subscript target is not an array or pointer")
  }
}

///|
fn struct_field_index_and_type(
  ty : @parser.CType,
  field_name : String,
) -> (Int, @parser.CType) raise {
  let fields = match ty.dataKind {
    Struct(_, fields) => fields
    Union(_, fields) => fields
    _ => raise SemanticError("Type '\{ty}' has no fields")
  }
  for i in 0..<fields.length() {
    let { name, ctype, .. } = fields[i]
    if name == field_name {
      return (i, ctype)
    }
  }
  raise SemanticError("Type '\{ty}' has no field named '\{field_name}'")
}

///|
fn Context::ctype_sizeof_bytes(
  self : Context,
  ty : @parser.CType,
) -> Int64 raise {
  // 直接使用 LLVM DataLayout 计算真实布局尺寸（含对齐/padding/平台指针宽度等）
  let llvm_ty = self.ctype_to_llvm_type(ty) catch {
    _ => raise Unimplemented("sizeof on unsupported type '\{ty}'")
  }
  let dl = self.llvm_mod.getDataLayout()
  dl.getTypeAllocSize(llvm_ty).to_int64()
}

///|
fn Context::emit_initializer_list_to_ptr(
  self : Context,
  base_ptr : &@IR.Value,
  ty : @parser.CType,
  inits : Array[@parser.Initializer],
) -> Unit raise {
  match ty.dataKind {
    Array(elem_ty, size) => {
      let arr_llvm_ty = self.ctype_to_llvm_type(ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      let mut i = 0
      while i < size {
        let v = if i < inits.length() {
          match inits[i].kind {
            AssignExpr(ae) => {
              let raw = self.emit_assign_expr(ae)
              self.cast_value_to_ctype(raw, ae.ctype, elem_ty)
            }
            InitializerList(inner) => {
              // 嵌套 initializer list：用临时 alloca 写入再 load（简化）
              let tmp = self.builder.createAlloca(
                self.ctype_to_llvm_type(elem_ty),
              )
              self.emit_initializer_list_to_ptr(tmp, elem_ty, inner)
              self.builder.createLoad(self.ctype_to_llvm_type(elem_ty), tmp)
            }
            _ =>
              raise Unimplemented(
                "Initializer kind not supported in array init",
              )
          }
        } else {
          self.llvm_ctx.getConstZero(self.ctype_to_llvm_type(elem_ty))
        }
        let idx = self.llvm_ctx.getConstInt32(i)
        let indices : Array[&@IR.Value] = Array::new()
        indices.push(zero)
        indices.push(idx)
        let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
        let _ = self.builder.createStore(v, elem_ptr)
        i = i + 1
      }
    }
    Struct(_, fields) => {
      let st_llvm_ty = self.ctype_to_llvm_type(ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      let mut i = 0
      while i < fields.length() && i < inits.length() {
        let { ctype: fty, .. } = fields[i]
        let indices : Array[&@IR.Value] = Array::new()
        indices.push(zero)
        indices.push(self.llvm_ctx.getConstInt32(i))
        let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
        match inits[i].kind {
          AssignExpr(ae) => {
            let raw = self.emit_assign_expr(ae)
            let v = self.cast_value_to_ctype(raw, ae.ctype, fty)
            let _ = self.builder.createStore(v, field_ptr)

          }
          InitializerList(inner) =>
            self.emit_initializer_list_to_ptr(field_ptr, fty, inner)
          _ =>
            raise Unimplemented("Initializer kind not supported in struct init")
        }
        i = i + 1
      }
    }
    _ => raise Unimplemented("Initializer list not implemented yet")
  }
}
