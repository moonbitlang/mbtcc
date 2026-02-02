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
fn Context::materialize_if_const(
  self : Context,
  val : &@IR.Value,
) -> &@IR.Value raise {
  if @unsafe.llvm_is_constant(val.getValueRef()) {
    let ty = val.getType()
    let slot = self.builder.createAlloca(ty)
    self.builder.createStore(val, slot) |> ignore
    (self.builder.createLoad(ty, slot) : &@IR.Value)
  } else {
    (val : &@IR.Value)
  }
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
      if val == 0 { (self.llvm_ctx.getConstFalse() : &@IR.Value) } else {
        (self.llvm_ctx.getConstTrue() : &@IR.Value)
      }
    Int8Type(_) => (self.llvm_ctx.getConstInt8(val) : &@IR.Value)
    Int16Type(_) => (self.llvm_ctx.getConstInt16(val) : &@IR.Value)
    Int32Type(_) => (self.llvm_ctx.getConstInt32(val) : &@IR.Value)
    Int64Type(_) => (self.llvm_ctx.getConstInt64(val.to_int64()) : &@IR.Value)
    PointerType(_) =>
      if val == 0 {
        (self.llvm_ctx.getConstPointerNull(llvm_ty) : &@IR.Value)
      } else {
        raise Unimplemented("Integer constant for type '\{ty}' not supported")
      }
    _ => raise Unimplemented("Integer constant for type '\{ty}' not supported")
  }
}

///|
struct BitFieldInfo {
  name : String
  ctype : @parser.CType
  bit_offset : Int
  bit_width : Int
}

///|
enum StructSlot {
  Normal(String, @parser.CType)
  Bitfield(@parser.CType, Array[BitFieldInfo])
  AlignMarker(@parser.CType)
}

///|
struct FieldAccess {
  ptr : &@IR.Value
  ctype : @parser.CType
  bit_offset : Int?
  bit_width : Int?
  container_ctype : @parser.CType?
}

///|
fn Context::bitfield_container_bits(
  self : Context,
  ty : @parser.CType,
) -> Int raise {
  let llvm_ty = self.ctype_to_llvm_type(ty)
  let dl = self.llvm_mod.getDataLayout()
  (dl.getTypeAllocSize(llvm_ty) * 8)
}

///|
fn Context::struct_layout_slots(
  self : Context,
  fields : Array[@parser.StructField],
) -> Array[StructSlot] raise {
  let slots : Array[StructSlot] = Array::new()
  let mut cur_container : @parser.CType? = None
  let mut cur_bits = 0
  let mut bit_offset = 0
  let mut bitfields : Array[BitFieldInfo] = Array::new()

  fn flush_container(
    slots : Array[StructSlot],
    cur_container : @parser.CType?,
    bitfields : Array[BitFieldInfo],
    bit_offset : Int,
  ) -> Unit {
    match cur_container {
      Some(cty) if bitfields.length() > 0 || bit_offset > 0 =>
        slots.push(StructSlot::Bitfield(cty, bitfields))
      _ => ()
    }
  }

  for f in fields {
    let { name, ctype, bit_width } = f
    match bit_width {
      None => {
        flush_container(slots, cur_container, bitfields, bit_offset)
        cur_container = None
        bitfields = Array::new()
        bit_offset = 0
        slots.push(StructSlot::Normal(name, ctype))
      }
      Some(w) => {
        if w == 0 {
          flush_container(slots, cur_container, bitfields, bit_offset)
          cur_container = None
          bitfields = Array::new()
          bit_offset = 0
          slots.push(StructSlot::AlignMarker(ctype))
          continue
        }
        let container_bits = self.bitfield_container_bits(ctype)
        if cur_container is None || cur_container.unwrap() != ctype ||
          bit_offset + w > container_bits {
          flush_container(slots, cur_container, bitfields, bit_offset)
          cur_container = Some(ctype)
          bitfields = Array::new()
          bit_offset = 0
          cur_bits = container_bits
        }
        if name != "" {
          bitfields.push(BitFieldInfo::{
            name,
            ctype,
            bit_offset,
            bit_width: w,
          })
        }
        bit_offset = bit_offset + w
        if bit_offset == cur_bits {
          flush_container(slots, cur_container, bitfields, bit_offset)
          cur_container = None
          bitfields = Array::new()
          bit_offset = 0
        }
      }
    }
  }
  flush_container(slots, cur_container, bitfields, bit_offset)
  slots
}

///|
fn Context::struct_slot_llvm_types(
  self : Context,
  slots : Array[StructSlot],
) -> Array[&@IR.Type] raise {
  let elem_tys : Array[&@IR.Type] = Array::new()
  for slot in slots {
    match slot {
      Normal(_, cty) => elem_tys.push(self.ctype_to_llvm_type(cty))
      Bitfield(cty, _) => elem_tys.push(self.ctype_to_llvm_type(cty))
      AlignMarker(cty) => {
        let elem = self.ctype_to_llvm_type(cty)
        elem_tys.push(self.llvm_ctx.getArrayType(elem, 0))
      }
    }
  }
  elem_tys
}

///|
fn Context::get_field_access(
  self : Context,
  base_ptr : &@IR.Value,
  base_ty : @parser.CType,
  field_name : String,
) -> FieldAccess raise {
  match base_ty.dataKind {
    Struct(_, fields) => {
      let slots = self.struct_layout_slots(fields)
      let st_llvm_ty = self.ctype_to_llvm_type(base_ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      for i in 0..<slots.length() {
        match slots[i] {
          Normal(name, cty) => {
            let indices : Array[&@IR.Value] = Array::new()
            indices.push(zero)
            indices.push(self.llvm_ctx.getConstInt32(i))
            let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
            if name == field_name {
              return FieldAccess::{
                ptr: field_ptr,
                ctype: cty,
                bit_offset: None,
                bit_width: None,
                container_ctype: None,
              }
            }
            if name == "" &&
              (cty.dataKind is Struct(_, _) || cty.dataKind is Union(_, _)) {
              let inner = self.get_field_access(field_ptr, cty, field_name) catch {
                _ => continue
              }
              return inner
            }
          }
          Bitfield(cty, bitfields) => {
            for bf in bitfields {
              if bf.name == field_name {
                let indices : Array[&@IR.Value] = Array::new()
                indices.push(zero)
                indices.push(self.llvm_ctx.getConstInt32(i))
                let field_ptr = self.builder.createGEP(base_ptr, st_llvm_ty, indices)
                return FieldAccess::{
                  ptr: field_ptr,
                  ctype: bf.ctype,
                  bit_offset: Some(bf.bit_offset),
                  bit_width: Some(bf.bit_width),
                  container_ctype: Some(cty),
                }
              }
            }
          }
          AlignMarker(_) => ()
        }
      }
      raise SemanticError("Type '\{base_ty}' has no field named '\{field_name}'")
    }
    Union(_, fields) => {
      for f in fields {
        let { name, ctype: fty, bit_width } = f
        if name == field_name {
          match bit_width {
            Some(w) => {
              return FieldAccess::{
                ptr: base_ptr,
                ctype: fty,
                bit_offset: Some(0),
                bit_width: Some(w),
                container_ctype: Some(fty),
              }
            }
            None =>
              return FieldAccess::{
                ptr: base_ptr,
                ctype: fty,
                bit_offset: None,
                bit_width: None,
                container_ctype: None,
              }
          }
        }
        if name == "" &&
          (fty.dataKind is Struct(_, _) || fty.dataKind is Union(_, _)) {
          let inner = self.get_field_access(base_ptr, fty, field_name) catch {
            _ => continue
          }
          return inner
        }
      }
      raise SemanticError("Type '\{base_ty}' has no field named '\{field_name}'")
    }
    _ => raise SemanticError("Type '\{base_ty}' has no fields")
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
  let tmp : &@IR.Value = if self.in_global_init {
    let name =
      "__mbtcc_compound_literal." + self.compound_literal_counter.to_string()
    self.compound_literal_counter += 1
    let zero = self.const_zero_constant(llvm_ty)
    let gv = self.llvm_mod.addGlobalVariable(
      llvm_ty,
      name,
      initializer=zero,
      linkage?=Some(InternalLinkage),
    )
    (gv : &@IR.Value)
  } else {
    (self.builder.createAlloca(llvm_ty) : &@IR.Value)
  }
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
  let acc = self.get_field_access(base_ptr, base_ty, field_name)
  match acc.bit_width {
    Some(_) =>
      raise SemanticError("Bitfield '\{field_name}' is not addressable")
    None => (acc.ptr, acc.ctype)
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
fn Context::store_aggregate_value(
  self : Context,
  dst_ptr : &@IR.Value,
  dst_ty : @parser.CType,
  val : &@IR.Value,
) -> Unit raise {
  let llvm_ty = self.ctype_to_llvm_type(dst_ty)
  let dl = self.llvm_mod.getDataLayout()
  let align = dl.getTypeAlignment(llvm_ty)
  let size = dl.getTypeAllocSize(llvm_ty)
  let size_val = self.llvm_ctx.getConstInt64(size.to_int64())
  match val.getType().asTypeEnum() {
    PointerType(_) => {
      let _ = self.builder.createMemCpy(dst_ptr, align, val, align, size_val)
      ()
    }
    _ => {
      self.builder.createStore(val, dst_ptr) |> ignore
    }
  }
}

///|
fn Context::emit_string_literal_to_array(
  self : Context,
  base_ptr : &@IR.Value,
  ty : @parser.CType,
  value : String,
  is_wide : Bool,
) -> Unit raise {
  guard ty.dataKind is Array(elem_ty, size0) else {
    raise SemanticError("String initializer target is not an array")
  }
  let mut size = size0
  if size == 0 {
    size = value.length() + 1
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
fn is_aggregate_type(ty : @parser.CType) -> Bool {
  match ty.dataKind {
    Array(_, _) | Struct(_, _) | Union(_, _) => true
    _ => false
  }
}

///|
fn consume_flat_inits_for_type(
  ty : @parser.CType,
  inits : Array[@parser.Initializer],
  start : Int,
) -> (Array[@parser.Initializer], Int) {
  if start >= inits.length() {
    return (Array::new(), start)
  }
  let init = inits[start]
  match init.kind {
    AssignExpr(ae) if is_aggregate_type(ae.ctype) => {
      let arr : Array[@parser.Initializer] = Array::new()
      arr.push(init)
      return (arr, start + 1)
    }
    Designation(_, _) | InitializerList(_) => {
      let arr : Array[@parser.Initializer] = Array::new()
      arr.push(init)
      return (arr, start + 1)
    }
    _ => ()
  }
  match ty.dataKind {
    Struct(_, fields) => {
      let res : Array[@parser.Initializer] = Array::new()
      let mut idx = start
      for f in fields {
        let (sub, next_idx) = consume_flat_inits_for_type(f.ctype, inits, idx)
        if sub.length() == 0 {
          break
        }
        for s in sub {
          res.push(s)
        }
        idx = next_idx
      }
      if res.length() == 0 {
        res.push(init)
        idx = start + 1
      }
      (res, idx)
    }
    Array(elem_ty, size) => {
      match init.kind {
        AssignExpr(_) if string_literal_from_initializer(init) is Some(_) => {
          let arr : Array[@parser.Initializer] = Array::new()
          arr.push(init)
          return (arr, start + 1)
        }
        _ => ()
      }
      let res : Array[@parser.Initializer] = Array::new()
      let mut idx = start
      let mut i = 0
      while i < size {
        let (sub, next_idx) = consume_flat_inits_for_type(elem_ty, inits, idx)
        if sub.length() == 0 {
          break
        }
        for s in sub {
          res.push(s)
        }
        idx = next_idx
        i = i + 1
      }
      if res.length() == 0 {
        res.push(init)
        idx = start + 1
      }
      (res, idx)
    }
    Union(_, fields) => {
      if fields.length() == 0 {
        let arr : Array[@parser.Initializer] = Array::new()
        arr.push(init)
        return (arr, start + 1)
      }
      let (sub, next_idx) = consume_flat_inits_for_type(
        fields[0].ctype,
        inits,
        start,
      )
      if sub.length() == 0 {
        let arr : Array[@parser.Initializer] = Array::new()
        arr.push(init)
        return (arr, start + 1)
      }
      (sub, next_idx)
    }
    _ => {
      let arr : Array[@parser.Initializer] = Array::new()
      arr.push(init)
      (arr, start + 1)
    }
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
      Range(_, _) =>
        raise SemanticError("Range designator must be handled in array init")
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
      let mut actual_size = size
      if actual_size == 0 {
        if inits.length() == 1 &&
          string_literal_from_initializer(inits[0]) is Some((s, _)) &&
          (elem_ty.dataKind is Char || elem_ty.dataKind is UChar) {
          actual_size = s.length() + 1
        } else {
          actual_size = inits.length()
        }
      }
      // Zero-initialize all elements first
      let arr_llvm_ty = self.ctype_to_llvm_type(ty)
      let zero = self.llvm_ctx.getConstInt32(0)
      let mut zi = 0
      while zi < actual_size {
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
      let mut init_idx = 0
      while init_idx < inits.length() {
        let init = inits[init_idx]
        match init.kind {
          Designation(desig, inner) => {
            match desig {
              Range(start_expr, end_expr) => {
                let start_idx = start_expr.eval_as_int()
                let end_idx = end_expr.eval_as_int()
                let arr_llvm_ty = self.ctype_to_llvm_type(ty)
                let zero = self.llvm_ctx.getConstInt32(0)
                let mut i = start_idx
                while i <= end_idx {
                  if i >= 0 && i < actual_size {
                    let indices : Array[&@IR.Value] = Array::new()
                    indices.push(zero)
                    indices.push(self.llvm_ctx.getConstInt32(i))
                    let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
                    self.emit_initializer_list_to_ptr(
                      elem_ptr,
                      elem_ty,
                      unwrap_init_list(inner),
                    )
                  }
                  i = i + 1
                }
                if end_idx + 1 > next_idx {
                  next_idx = end_idx + 1
                }
              }
              _ => {
                let (ptr, dst_ty) = apply_designator(self, base_ptr, ty, desig)
                self.emit_initializer_list_to_ptr(
                  ptr,
                  dst_ty,
                  unwrap_init_list(inner),
                )
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
            }
            init_idx = init_idx + 1
          }
          AssignExpr(ae) => {
            match string_literal_from_initializer(init) {
              Some((s, wide)) if elem_ty.dataKind is Char || elem_ty.dataKind is UChar => {
                self.emit_string_literal_to_array(base_ptr, ty, s, wide)
                next_idx = actual_size
                init_idx = init_idx + 1
                continue
              }
              _ => ()
            }
            if next_idx >= actual_size {
              init_idx = init_idx + 1
              continue
            }
            let idx = self.llvm_ctx.getConstInt32(next_idx)
            let indices : Array[&@IR.Value] = Array::new()
            indices.push(zero)
            indices.push(idx)
            let elem_ptr = self.builder.createGEP(base_ptr, arr_llvm_ty, indices)
            if is_aggregate_type(elem_ty) {
              let (group, next_init_idx) =
                consume_flat_inits_for_type(elem_ty, inits, init_idx)
              if group.length() > 0 {
                self.emit_initializer_list_to_ptr(elem_ptr, elem_ty, group)
                init_idx = next_init_idx
              } else {
                init_idx = init_idx + 1
              }
            } else {
              let raw = self.emit_assign_expr(ae)
              let v = self.cast_value_to_ctype(raw, ae.ctype, elem_ty)
              let _ = self.builder.createStore(v, elem_ptr)
              init_idx = init_idx + 1
            }
            next_idx = next_idx + 1
          }
          InitializerList(inner) => {
            if next_idx >= actual_size {
              init_idx = init_idx + 1
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
            init_idx = init_idx + 1
          }
          _ =>
            raise Unimplemented(
              "Initializer kind not supported in array init",
            )
        }
      }
    }
    Struct(_, fields) => {
      if inits.length() == 1 {
        match inits[0].kind {
          AssignExpr(ae) if is_aggregate_type(ae.ctype) => {
            let v = self.emit_assign_expr(ae)
            self.store_aggregate_value(base_ptr, ty, v)
            return
          }
          _ => ()
        }
      }
      // Zero-initialize the whole struct first (covers bitfields too).
      let z = self.const_zero_value(self.ctype_to_llvm_type(ty))
      let _ = self.builder.createStore(z, base_ptr)
      let mut next_idx = 0
      let mut init_idx = 0
      while init_idx < inits.length() {
        let init = inits[init_idx]
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
            init_idx = init_idx + 1
          }
          AssignExpr(ae) => {
            if next_idx >= fields.length() {
              init_idx = init_idx + 1
              continue
            }
            // Skip unnamed bitfields (they don't consume initializers).
            let mut skip = true
            let mut fty : @parser.CType = fields[next_idx].ctype
            let mut fbit : Int? = fields[next_idx].bit_width
            let mut fname = fields[next_idx].name
            while fbit is Some(_) && fname == "" {
              next_idx = next_idx + 1
              if next_idx >= fields.length() {
                init_idx = init_idx + 1
                skip = false
                break
              }
              fty = fields[next_idx].ctype
              fbit = fields[next_idx].bit_width
              fname = fields[next_idx].name
            }
            if !skip {
              continue
            }
            let mut field_ptr : &@IR.Value = base_ptr
            if is_aggregate_type(fty) {
              let (group, next_init_idx) =
                consume_flat_inits_for_type(fty, inits, init_idx)
              if group.length() > 0 {
                let acc = self.get_field_access(base_ptr, ty, fname)
                self.emit_initializer_list_to_ptr(acc.ptr, fty, group)
                init_idx = next_init_idx
              } else {
                init_idx = init_idx + 1
              }
            } else {
              match string_literal_from_initializer(init) {
                Some((s, wide)) if fty.dataKind is Array(_, _) => {
                  let acc = self.get_field_access(base_ptr, ty, fname)
                  self.emit_string_literal_to_array(acc.ptr, fty, s, wide)
                }
                _ if fty.dataKind is Union(_, _) => {
                  let acc = self.get_field_access(base_ptr, ty, fname)
                  self.emit_initializer_list_to_ptr(acc.ptr, fty, [init])
                }
                _ => {
                  match ae.ctype.dataKind {
                    Struct(_, _) | Union(_, _) => {
                      let loc = init.tokens[0]
                      raise SemanticError(
                        "Aggregate initializer used for scalar field at \{loc}",
                      )
                    }
                    _ => ()
                  }
                  let raw = self.emit_assign_expr(ae)
                  let acc = self.get_field_access(base_ptr, ty, fname)
                  match (acc.bit_width, acc.bit_offset) {
                    (Some(w), Some(off)) => {
                      let container_ty = acc.container_ctype.unwrap()
                      let llvm_cty = self.ctype_to_llvm_type(container_ty)
                      let old =
                        (self.builder.createLoad(llvm_cty, acc.ptr) : &@IR.Value)
                      let mask_val = if w >= 64 { -1 } else { (1 << w) - 1 }
                      let mask = self.const_int_for_ctype(container_ty, mask_val)
                      let shift = self.const_int_for_ctype(container_ty, off)
                      let field_mask = self.builder.createShl(mask, shift)
                      let v0 = self.cast_value_to_ctype(raw, ae.ctype, acc.ctype)
                      let v1 =
                        self.cast_value_to_ctype(v0, acc.ctype, container_ty)
                      let v2 = self.builder.createAnd(v1, mask)
                      let vshift = self.builder.createShl(v2, shift)
                      let cleared = self.builder.createAnd(
                        old,
                        self.builder.createNot(field_mask),
                      )
                      let merged = self.builder.createOr(cleared, vshift)
                      let _ = self.builder.createStore(merged, acc.ptr)
                    }
                    _ => {
                      let v = self.cast_value_to_ctype(raw, ae.ctype, fty)
                      let _ = self.builder.createStore(v, acc.ptr)
                    }
                  }
                }
              }
              init_idx = init_idx + 1
            }
            next_idx = next_idx + 1
          }
          InitializerList(inner) => {
            if next_idx >= fields.length() {
              init_idx = init_idx + 1
              continue
            }
            // Skip unnamed bitfields
            let mut fty : @parser.CType = fields[next_idx].ctype
            let mut fbit : Int? = fields[next_idx].bit_width
            let mut fname = fields[next_idx].name
            while fbit is Some(_) && fname == "" {
              next_idx = next_idx + 1
              if next_idx >= fields.length() {
                init_idx = init_idx + 1
                fbit = None
                break
              }
              fty = fields[next_idx].ctype
              fbit = fields[next_idx].bit_width
              fname = fields[next_idx].name
            }
            if next_idx < fields.length() {
              let acc = self.get_field_access(base_ptr, ty, fname)
              self.emit_initializer_list_to_ptr(acc.ptr, fty, inner)
            }
            next_idx = next_idx + 1
            init_idx = init_idx + 1
          }
          _ =>
            raise Unimplemented("Initializer kind not supported in struct init")
        }
      }
    }
    Union(_, fields) => {
      guard fields.length() > 0 else { return }
      if inits.length() == 1 {
        match inits[0].kind {
          AssignExpr(ae) if is_aggregate_type(ae.ctype) => {
            let v = self.emit_assign_expr(ae)
            self.store_aggregate_value(base_ptr, ty, v)
            return
          }
          _ => ()
        }
      }
      // Zero-initialize the union storage first
      let z = self.const_zero_value(self.ctype_to_llvm_type(ty))
      let _ = self.builder.createStore(z, base_ptr)
      if inits.length() == 0 {
        return
      }
      let mut all_designation = true
      for init in inits {
        match init.kind {
          Designation(_, _) => ()
          _ => {
            all_designation = false
            break
          }
        }
      }
      if all_designation {
        for init in inits {
          match init.kind {
            Designation(desig, inner) => {
              let (ptr, dst_ty) = apply_designator(self, base_ptr, ty, desig)
              self.emit_initializer_list_to_ptr(
                ptr,
                dst_ty,
                unwrap_init_list(inner),
              )
            }
            _ => ()
          }
        }
        return
      }
      match inits[0].kind {
        Designation(desig, inner) => {
          let (ptr, dst_ty) = apply_designator(self, base_ptr, ty, desig)
          self.emit_initializer_list_to_ptr(ptr, dst_ty, unwrap_init_list(inner))
        }
        AssignExpr(ae) => {
          let fty = fields[0].ctype
          if is_aggregate_type(fty) {
            let (group, _) = consume_flat_inits_for_type(fty, inits, 0)
            if group.length() > 0 {
              self.emit_initializer_list_to_ptr(base_ptr, fty, group)
            }
          } else {
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
