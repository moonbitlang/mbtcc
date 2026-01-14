///|
pub fn Context::ctype_kind_to_llvm_type(
  self : Context,
  dataKind : @parser.CTypeDataKind,
) -> &@IR.Type raise {
  let { llvm_ctx, .. } = self
  match dataKind {
    Void => (llvm_ctx.getVoidTy() : &@IR.Type)
    Char => llvm_ctx.getInt8Ty()
    UChar => llvm_ctx.getInt8Ty()
    Int16 => llvm_ctx.getInt16Ty()
    UInt16 => llvm_ctx.getInt16Ty()
    Int => llvm_ctx.getInt32Ty()
    UInt => llvm_ctx.getInt32Ty()
    Long => llvm_ctx.getInt64Ty()
    ULong => llvm_ctx.getInt64Ty()
    LongLong => llvm_ctx.getInt64Ty()
    ULongLong => llvm_ctx.getInt64Ty()
    Float => llvm_ctx.getFloatTy()
    Double => llvm_ctx.getDoubleTy()
    LongDouble => llvm_ctx.getFP128Ty()
    Ptr(_) => llvm_ctx.getPtrTy()
    Struct(name, _) =>
      match llvm_ctx.getStructTypeByName(name) {
        Some(ty) => ty
        None =>
          raise IllegalLLVMUsage(
            "Struct type '\{name}' not found in LLVM context",
          )
      }
    Array(ty, size) => {
      let elem_ty = self.ctype_to_llvm_type(ty)
      llvm_ctx.getArrayType(elem_ty, size)
    }
    // Enums are represented as 32-bit integers in LLVM
    Enum(_) => llvm_ctx.getInt32Ty()
    Union(_) =>
      raise IllegalLLVMUsage(
        "Union types are not directly representable in LLVM types",
      )
    Function(_) =>
      raise IllegalLLVMUsage(
        "Function types are not directly representable in LLVM types",
      )
  }
}

///|
pub fn Context::ctype_to_llvm_type(
  self : Context,
  ctype : @parser.CType,
) -> &@IR.Type raise {
  self.ctype_kind_to_llvm_type(ctype.dataKind)
}

///|
fn is_integral_kind(kind : @parser.CTypeDataKind) -> Bool {
  match kind {
    Char | UChar => true
    Int16 | UInt16 => true
    Int | UInt => true
    Long | ULong | LongLong | ULongLong => true
    _ => false
  }
}

///|
fn is_floating_kind(kind : @parser.CTypeDataKind) -> Bool {
  match kind {
    Float | Double | LongDouble => true
    _ => false
  }
}

///|
fn is_unsigned_kind(kind : @parser.CTypeDataKind) -> Bool {
  match kind {
    UChar | UInt16 | UInt | ULong | ULongLong => true
    _ => false
  }
}

///|
fn Context::cast_value_to_ctype(
  self : Context,
  val : &@IR.Value,
  from_ctype : @parser.CType,
  to_ctype : @parser.CType,
) -> &@IR.Value raise {
  if from_ctype == to_ctype {
    return val
  }
  let from_kind = from_ctype.dataKind
  let to_kind = to_ctype.dataKind
  // Numeric conversions
  if is_integral_kind(from_kind) && is_integral_kind(to_kind) {
    let target_ty = self.ctype_to_llvm_type(to_ctype)
    let to_int_ty = target_ty.tryAsIntType().unwrap()
    let from_ty = val.getType().tryAsIntType().unwrap()
    let from_width = from_ty.getBitWidth()
    let to_width = to_int_ty.getBitWidth()
    if from_width == to_width {
      val
    } else if from_width < to_width {
      if from_width == 1 {
        self.builder.createZExt(val, to_int_ty)
      } else if is_unsigned_kind(from_kind) {
        self.builder.createZExt(val, to_int_ty)
      } else {
        self.builder.createSExt(val, to_int_ty)
      }
    } else {
      self.builder.createTrunc(val, to_int_ty)
    }
  } else if is_integral_kind(from_kind) && is_floating_kind(to_kind) {
    let target_ty = self.ctype_to_llvm_type(to_ctype).tryAsFPType().unwrap()
    if is_unsigned_kind(from_kind) {
      self.builder.createUIToFP(val, target_ty)
    } else {
      self.builder.createSIToFP(val, target_ty)
    }
  } else if is_floating_kind(from_kind) && is_integral_kind(to_kind) {
    let target_ty = self.ctype_to_llvm_type(to_ctype).tryAsIntType().unwrap()
    if is_unsigned_kind(to_kind) {
      self.builder.createFPToUI(val, target_ty)
    } else {
      self.builder.createFPToSI(val, target_ty)
    }
  } else if is_floating_kind(from_kind) && is_floating_kind(to_kind) {
    let target_ty = self.ctype_to_llvm_type(to_ctype).tryAsFPType().unwrap()
    let from_ty = val.getType().tryAsFPType().unwrap()
    let from_width = from_ty.getBitWidth()
    let to_width = target_ty.getBitWidth()
    if from_width == to_width {
      val
    } else if from_width < to_width {
      self.builder.createFPExt(val, target_ty)
    } else {
      self.builder.createFPTrunc(val, target_ty)
    }
  } else if from_kind is Ptr(_) && is_integral_kind(to_kind) {
    let to_int_ty = self.ctype_to_llvm_type(to_ctype).tryAsIntType().unwrap()
    self.builder.createPtrToInt(val, to_int_ty)
  } else if is_integral_kind(from_kind) && to_kind is Ptr(_) {
    println(
      "Compiler ICE: int to pointer cast '\{from_ctype}' -> '\{to_ctype}' not supported",
    )
    panic()
  } else if from_kind is Ptr(_) && to_kind is Ptr(_) {
    // 在当前实现里，所有指针类型的 LLVM 类型都统一为 `ptr`，因此不同指针类型之间转换是 no-op
    val
  } else if from_kind is Function(_, _, ..) && to_kind is Ptr(_) {
    // 函数在表达式中会退化为函数指针；MoonLLVM 里函数值可直接作为 ptr 使用
    val
  } else {
    println(
      "Compiler ICE: cannot cast value from '\{from_ctype}' to '\{to_ctype}'",
    )
    panic()
  }
}
