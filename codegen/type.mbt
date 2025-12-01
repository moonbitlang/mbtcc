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
