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
fn Context::const_zero_constant(
  self : Context,
  ty : &@IR.Type,
) -> &@IR.Constant raise CodeGenError {
  match ty.asTypeEnum() {
    Int1Type(_) => self.llvm_ctx.getConstFalse() as &@IR.Constant
    Int8Type(_) => self.llvm_ctx.getConstInt8(0) as &@IR.Constant
    Int16Type(_) => self.llvm_ctx.getConstInt16(0) as &@IR.Constant
    Int32Type(_) => self.llvm_ctx.getConstInt32(0) as &@IR.Constant
    Int64Type(_) => self.llvm_ctx.getConstInt64(0) as &@IR.Constant
    FloatType(_) =>
      self.llvm_ctx.getConstZeroFloat(isNegative=false) as &@IR.Constant
    DoubleType(_) =>
      self.llvm_ctx.getConstZeroDouble(isNegative=false) as &@IR.Constant
    FP128Type(_) =>
      self.llvm_ctx.getConstZeroFP128(isNegative=false) as &@IR.Constant
    PointerType(ptr_ty) => self.llvm_ctx.getConstPointerNull(ptr_ty)
    ArrayType(arr_ty) => {
      let elem_ty = arr_ty.getElementType()
      let count = arr_ty.getElementCount()
      let elems : Array[&@IR.Constant] = Array::new()
      for _ in 0..<count {
        elems.push(self.const_zero_constant(elem_ty))
      }
      self.llvm_ctx.getConstArray(elem_ty, elems)
    }
    StructType(sty) => {
      let elems : Array[&@IR.Constant] = Array::new()
      for elem_ty in sty.elements() {
        elems.push(self.const_zero_constant(elem_ty))
      }
      if sty.isLiteral() {
        self.llvm_ctx.getConstStruct(elems)
      } else {
        self.llvm_ctx.getConstNamedStruct(sty, elems)
      }
    }
    _ => raise Unimplemented("Zero constant for type '\{ty}' not supported")
  }
}

///|
fn Context::const_zero_value(
  self : Context,
  ty : &@IR.Type,
) -> &@IR.Value raise CodeGenError {
  self.const_zero_constant(ty)
}

///|
fn Context::const_one_value(
  self : Context,
  ty : &@IR.Type,
) -> &@IR.Value raise CodeGenError {
  match ty.asTypeEnum() {
    Int1Type(_) => self.llvm_ctx.getConstTrue() as &@IR.Value
    Int8Type(_) => self.llvm_ctx.getConstInt8(1) as &@IR.Value
    Int16Type(_) => self.llvm_ctx.getConstInt16(1) as &@IR.Value
    Int32Type(_) => self.llvm_ctx.getConstInt32(1) as &@IR.Value
    Int64Type(_) => self.llvm_ctx.getConstInt64(1) as &@IR.Value
    FloatType(_) => self.llvm_ctx.getConstFloat(1.0) as &@IR.Value
    DoubleType(_) => self.llvm_ctx.getConstDouble(1.0) as &@IR.Value
    FP128Type(_) => self.llvm_ctx.getConstFP128(1.0) as &@IR.Value
    _ => raise Unimplemented("One constant for type '\{ty}' not supported")
  }
}

///|
fn Context::const_int_for_ctype(
  self : Context,
  ty : @parser.CType,
  val : Int,
) -> &@IR.Value raise {
  let llvm_ty = self.ctype_to_llvm_type(ty)
  match llvm_ty.asTypeEnum() {
    Int1Type(_) =>
      if val == 0 { self.llvm_ctx.getConstFalse() } else {
        self.llvm_ctx.getConstTrue()
      }
    Int8Type(_) => self.llvm_ctx.getConstInt8(val)
    Int16Type(_) => self.llvm_ctx.getConstInt16(val)
    Int32Type(_) => self.llvm_ctx.getConstInt32(val)
    Int64Type(_) => self.llvm_ctx.getConstInt64(val.to_int64())
    _ => raise Unimplemented("Integer constant for type '\{ty}' not supported")
  }
}

///|
fn string_literal_from_initializer(
  init : @parser.Initializer,
) -> (String, Bool)? {
  let mut s = ""
  let mut saw = false
  let mut is_wide = false
  for tok in init.tokens {
    match tok.kind {
      String(v) => {
        s = s + v
        saw = true
        if tok.raw.strip_prefix("L\"") is Some(_) {
          is_wide = true
        }
      }
      _ => return None
    }
  }
  if saw { Some((s, is_wide)) } else { None }
}

///|
fn Context::emit_compound_literal_ptr(
  self : Context,
  ty : @parser.CType,
  init : @parser.Initializer,
) -> &@IR.Value raise {
  let llvm_ty = self.ctype_to_llvm_type(ty)
  let tmp = self.builder.createAlloca(llvm_ty)
  match init.kind {
    AssignExpr(ae) => {
      match string_literal_from_initializer(init) {
        Some((s, wide)) if ty.dataKind is Array(_, _) =>
          self.emit_string_literal_to_array(tmp, ty, s, wide)
        _ => {
          let v = self.emit_assign_expr(ae)
          let v = self.cast_value_to_ctype(v, ae.ctype, ty)
          self.builder.createStore(v, tmp) |> ignore
        }
      }
    }
    InitializerList(list) => self.emit_initializer_list_to_ptr(tmp, ty, list)
    Designation(_, _) => self.emit_initializer_list_to_ptr(tmp, ty, [init])
  }
  tmp
}

///|
/// Compute `arr[idx]` element address (for both lvalue and rvalue load)
fn Context::emit_array_access_ptr(
  self : Context,
  arr_expr : @parser.PostfixExpr,
  idx_expr : @parser.Expr,
) -> (&@IR.Value, @parser.CType) raise {
  match arr_expr.ctype.dataKind {
    Ptr(elem_ty) => {
      let idx_raw = self.emit_expr(idx_expr)
      let idx_i32 = self.cast_value_to_ctype(
        idx_raw,
        idx_expr.ctype,
        @parser.CType::int(),
      )
      let base_ptr = self.emit_postfix_expr(arr_expr)
      let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(idx_i32)
      let elem_ptr = self.builder.createGEP(base_ptr, elem_llvm_ty, indices)
      (elem_ptr, elem_ty)
    }
    Array(elem_ty, _) => {
      let idx_raw = self.emit_expr(idx_expr)
      let idx_i32 = self.cast_value_to_ctype(
        idx_raw,
        idx_expr.ctype,
        @parser.CType::int(),
      )
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
      match idx_expr.ctype.dataKind {
        Ptr(elem_ty) => {
          let idx_raw = self.emit_postfix_expr(arr_expr)
          let idx_i32 = self.cast_value_to_ctype(
            idx_raw,
            arr_expr.ctype,
            @parser.CType::int(),
          )
          let base_ptr = self.emit_expr(idx_expr)
          let elem_llvm_ty = self.ctype_to_llvm_type(elem_ty)
          let indices : Array[&@IR.Value] = Array::new()
          indices.push(idx_i32)
          let elem_ptr = self.builder.createGEP(base_ptr, elem_llvm_ty, indices)
          (elem_ptr, elem_ty)
        }
        Array(elem_ty, _) => {
          let idx_raw = self.emit_postfix_expr(arr_expr)
          let idx_i32 = self.cast_value_to_ctype(
            idx_raw,
            arr_expr.ctype,
            @parser.CType::int(),
          )
          let (base_ptr, _) = self.get_lvalue_ptr_from_paren_expr(idx_expr)
          let arr_llvm_ty = self.ctype_to_llvm_type(idx_expr.ctype)
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
}

///|
fn struct_field_index_and_type(
  ty : @parser.CType,
  field_name : String,
) -> (Int, @parser.CType) raise {
  let fields = match ty.dataKind {
    Struct(_, fields) => fields
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
fn Context::get_field_ptr_and_type(
  self : Context,
  base_ptr : &@IR.Value,
  base_ty : @parser.CType,
  field_name : String,
) -> (&@IR.Value, @parser.CType) raise {
  match base_ty.dataKind {
    Struct(_, fields) => {
      let st_llvm_ty = self.ctype_to_llvm_type(base_ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      for i in 0..<fields.length() {
        let { name, ctype: fty, .. } = fields[i]
        let indices : Array[&@IR.Value] = Array::new()
        indices.push(zero)
        indices.push(self.llvm_ctx.getConstInt32(i))
        let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
        if name == field_name {
          return (field_ptr, fty)
        }
        if name == "" &&
          (fty.dataKind is Struct(_, _) || fty.dataKind is Union(_, _)) {
          match self.try_get_field_ptr_and_type(field_ptr, fty, field_name) {
            Some((p, t)) => return (p, t)
            None => ()
          }
        }
      }
      raise SemanticError("Type '\{base_ty}' has no field named '\{field_name}'")
    }
    Union(_, fields) => {
      for i in 0..<fields.length() {
        let { name, ctype: fty, .. } = fields[i]
        if name == field_name {
          return (base_ptr, fty)
        }
        if name == "" &&
          (fty.dataKind is Struct(_, _) || fty.dataKind is Union(_, _)) {
          match self.try_get_field_ptr_and_type(base_ptr, fty, field_name) {
            Some((p, t)) => return (p, t)
            None => ()
          }
        }
      }
      raise SemanticError("Type '\{base_ty}' has no field named '\{field_name}'")
    }
    _ => raise SemanticError("Type '\{base_ty}' has no fields")
  }
}

///|
fn Context::try_get_field_ptr_and_type(
  self : Context,
  base_ptr : &@IR.Value,
  base_ty : @parser.CType,
  field_name : String,
) -> (&@IR.Value, @parser.CType)? {
  let res = self.get_field_ptr_and_type(base_ptr, base_ty, field_name) catch {
    _ => return None
  }
  Some(res)
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
fn Context::emit_string_literal_to_array(
  self : Context,
  base_ptr : &@IR.Value,
  ty : @parser.CType,
  value : String,
  is_wide : Bool,
) -> Unit raise {
  guard ty.dataKind is Array(elem_ty, size) else {
    raise SemanticError("String initializer target is not an array")
  }
  let arr_llvm_ty = self.ctype_to_llvm_type(ty)
  let zero = self.llvm_ctx.getConstInt32(0)
  let mut idx = 0
  if is_wide {
    for ch in value {
      if idx >= size {
        break
      }
      let v = self.const_int_for_ctype(elem_ty, ch.to_int())
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(self.llvm_ctx.getConstInt32(idx))
      let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
      let _ = self.builder.createStore(v, elem_ptr)
      idx = idx + 1
    }
  } else {
    let bytes = @utf8.encode(value)
    let mut bi = 0
    while bi < bytes.length() && idx < size {
      let b = bytes[bi].to_int()
      let v = self.const_int_for_ctype(elem_ty, b)
      let indices : Array[&@IR.Value] = Array::new()
      indices.push(zero)
      indices.push(self.llvm_ctx.getConstInt32(idx))
      let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
      let _ = self.builder.createStore(v, elem_ptr)
      bi = bi + 1
      idx = idx + 1
    }
  }
  if idx < size {
    let indices : Array[&@IR.Value] = Array::new()
    indices.push(zero)
    indices.push(self.llvm_ctx.getConstInt32(idx))
    let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
    let z = self.const_int_for_ctype(elem_ty, 0)
    let _ = self.builder.createStore(z, elem_ptr)
  }
}

///|
fn Context::emit_initializer_list_to_ptr(
  self : Context,
  base_ptr : &@IR.Value,
  ty : @parser.CType,
  inits : Array[@parser.Initializer],
) -> Unit raise {
  fn unwrap_init_list(init : @parser.Initializer) -> Array[@parser.Initializer] {
    match init.kind {
      InitializerList(inner) => inner
      _ => [init]
    }
  }
  fn apply_designator(
    self : Context,
    base_ptr : &@IR.Value,
    base_ty : @parser.CType,
    designator : @parser.Designator,
  ) -> (&@IR.Value, @parser.CType) raise {
    match designator {
      Field(name) =>
        match base_ty.dataKind {
          Struct(_, _) | Union(_, _) =>
            self.get_field_ptr_and_type(base_ptr, base_ty, name)
          _ => raise SemanticError("Designator '.\{name}' on non-aggregate type")
        }
      Index(const_expr) => {
        guard base_ty.dataKind is Array(elem_ty, _) else {
          raise SemanticError("Index designator on non-array type")
        }
        let idx = const_expr.eval_as_int()
        let arr_llvm_ty = self.ctype_to_llvm_type(base_ty)
        let zero = self.llvm_ctx.getConstInt32(0)
        let indices : Array[&@IR.Value] = Array::new()
        indices.push(zero)
        indices.push(self.llvm_ctx.getConstInt32(idx))
        let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
        (elem_ptr, elem_ty)
      }
      DesignatorList(desigs) => {
        let mut ptr = base_ptr
        let mut cur_ty = base_ty
        for d in desigs {
          let (p, t) = apply_designator(self, ptr, cur_ty, d)
          ptr = p
          cur_ty = t
        }
        (ptr, cur_ty)
      }
    }
  }
  match ty.dataKind {
    Array(elem_ty, size) => {
      // Zero-initialize all elements first
      let arr_llvm_ty = self.ctype_to_llvm_type(ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      let mut zi = 0
      while zi < size {
        let idx = self.llvm_ctx.getConstInt32(zi)
        let indices : Array[&@IR.Value] = Array::new()
        indices.push(zero)
        indices.push(idx)
        let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
        let z = self.const_zero_value(self.ctype_to_llvm_type(elem_ty))
        let _ = self.builder.createStore(z, elem_ptr)
        zi = zi + 1
      }
      let mut next_idx = 0
      for init in inits {
        match init.kind {
          Designation(desig, inner) => {
            let (ptr, dst_ty) = apply_designator(self, base_ptr, ty, desig)
            self.emit_initializer_list_to_ptr(ptr, dst_ty, unwrap_init_list(inner))
            let idx_opt = match desig {
              Index(const_expr) => Some(const_expr.eval_as_int())
              DesignatorList(desigs) => {
                let mut found : Int? = None
                for d in desigs {
                  match d {
                    Index(const_expr) => {
                      found = Some(const_expr.eval_as_int())
                      break
                    }
                    _ => ()
                  }
                }
                found
              }
              _ => None
            }
            match idx_opt {
              Some(idx) if idx + 1 > next_idx => next_idx = idx + 1
              _ => ()
            }
          }
          AssignExpr(ae) => {
            match string_literal_from_initializer(init) {
              Some((s, wide)) => {
                self.emit_string_literal_to_array(base_ptr, ty, s, wide)
                next_idx = size
                continue
              }
              None => ()
            }
            if next_idx >= size {
              continue
            }
            let raw = self.emit_assign_expr(ae)
            let v = self.cast_value_to_ctype(raw, ae.ctype, elem_ty)
            let idx = self.llvm_ctx.getConstInt32(next_idx)
            let indices : Array[&@IR.Value] = Array::new()
            indices.push(zero)
            indices.push(idx)
            let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
            let _ = self.builder.createStore(v, elem_ptr)
            next_idx = next_idx + 1
          }
          InitializerList(inner) => {
            if next_idx >= size {
              continue
            }
            let tmp = self.builder.createAlloca(
              self.ctype_to_llvm_type(elem_ty),
            )
            self.emit_initializer_list_to_ptr(tmp, elem_ty, inner)
            let v =
              (self.builder.createLoad(self.ctype_to_llvm_type(elem_ty), tmp) : &@IR.Value)
            let idx = self.llvm_ctx.getConstInt32(next_idx)
            let indices : Array[&@IR.Value] = Array::new()
            indices.push(zero)
            indices.push(idx)
            let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
            let _ = self.builder.createStore(v, elem_ptr)
            next_idx = next_idx + 1
          }
          _ =>
            raise Unimplemented(
              "Initializer kind not supported in array init",
            )
        }
      }
    }
    Struct(_, fields) => {
      let st_llvm_ty = self.ctype_to_llvm_type(ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      // Zero-initialize all fields first
      for i in 0..<fields.length() {
        let { ctype: fty, .. } = fields[i]
        let indices : Array[&@IR.Value] = Array::new()
        indices.push(zero)
        indices.push(self.llvm_ctx.getConstInt32(i))
        let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
        let z = self.const_zero_value(self.ctype_to_llvm_type(fty))
        let _ = self.builder.createStore(z, field_ptr)
      }
      let mut next_idx = 0
      for init in inits {
        match init.kind {
          Designation(desig, inner) => {
            let (ptr, dst_ty) = apply_designator(self, base_ptr, ty, desig)
            self.emit_initializer_list_to_ptr(ptr, dst_ty, unwrap_init_list(inner))
            // Advance sequential index if possible (best-effort)
            match desig {
              Field(name) => {
                for j in 0..<fields.length() {
                  if fields[j].name == name {
                    next_idx = j + 1
                    break
                  }
                }
              }
              _ => ()
            }
          }
          AssignExpr(ae) => {
            if next_idx >= fields.length() {
              continue
            }
            let { ctype: fty, .. } = fields[next_idx]
            let indices : Array[&@IR.Value] = Array::new()
            indices.push(zero)
            indices.push(self.llvm_ctx.getConstInt32(next_idx))
            let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
            match string_literal_from_initializer(init) {
              Some((s, wide)) if fty.dataKind is Array(_, _) => {
                self.emit_string_literal_to_array(field_ptr, fty, s, wide)
              }
              _ if fty.dataKind is Union(_, _) => {
                self.emit_initializer_list_to_ptr(field_ptr, fty, [init])
              }
              _ => {
                let raw = self.emit_assign_expr(ae)
                let v = self.cast_value_to_ctype(raw, ae.ctype, fty)
                let _ = self.builder.createStore(v, field_ptr)
              }
            }
            next_idx = next_idx + 1
          }
          InitializerList(inner) => {
            if next_idx >= fields.length() {
              continue
            }
            let { ctype: fty, .. } = fields[next_idx]
            let indices : Array[&@IR.Value] = Array::new()
            indices.push(zero)
            indices.push(self.llvm_ctx.getConstInt32(next_idx))
            let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
            self.emit_initializer_list_to_ptr(field_ptr, fty, inner)
            next_idx = next_idx + 1
          }
          _ =>
            raise Unimplemented("Initializer kind not supported in struct init")
        }
      }
    }
    Union(_, fields) => {
      guard fields.length() > 0 else { return }
      // Zero-initialize the union storage first
      let z = self.const_zero_value(self.ctype_to_llvm_type(ty))
      let _ = self.builder.createStore(z, base_ptr)
      if inits.length() == 0 {
        return
      }
      match inits[0].kind {
        Designation(desig, inner) => {
          let (ptr, dst_ty) = apply_designator(self, base_ptr, ty, desig)
          self.emit_initializer_list_to_ptr(ptr, dst_ty, unwrap_init_list(inner))
        }
        AssignExpr(ae) => {
          let fty = fields[0].ctype
          match string_literal_from_initializer(inits[0]) {
            Some((s, wide)) if fty.dataKind is Array(_, _) => {
              self.emit_string_literal_to_array(base_ptr, fty, s, wide)
            }
            _ => {
              let raw = self.emit_assign_expr(ae)
              let v = self.cast_value_to_ctype(raw, ae.ctype, fty)
              let _ = self.builder.createStore(v, base_ptr)
            }
          }
        }
        InitializerList(inner) => {
          let fty = fields[0].ctype
          self.emit_initializer_list_to_ptr(base_ptr, fty, inner)
        }
        _ => raise Unimplemented("Initializer kind not supported in union init")
      }
    }
    _ => {
      // Scalar or other non-aggregate types: accept a single assign expr
      guard inits.length() > 0 else { return }
      match inits[0].kind {
        AssignExpr(ae) => {
          let raw = self.emit_assign_expr(ae)
          let v = self.cast_value_to_ctype(raw, ae.ctype, ty)
          let _ = self.builder.createStore(v, base_ptr)
        }
        InitializerList(inner) =>
          self.emit_initializer_list_to_ptr(base_ptr, ty, inner)
        _ =>
          raise Unimplemented("Initializer list not implemented yet")
      }
    }
  }
}
