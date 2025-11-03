
pub(all) struct CType {
  dataKind: CTypeDataKind
  is_pointer: Bool
  is_const: Bool
  is_volatile: Bool
  is_restrict: Bool
  is_atomic: Bool
  is_static: Bool
  is_thread_local: Bool
  is_extern: Bool
}

pub fn CType::default_with(kind: CTypeDataKind) -> CType {
  return CType::{
    dataKind: kind,
    is_pointer: false,
    is_const: false,
    is_volatile: false,
    is_restrict: false,
    is_atomic: false,
    is_static: false,
    is_thread_local: false,
    is_extern: false,
  }
}

pub(all) enum CTypeDataKind {
  Void   // void
  Char   // char
  UChar  // unsigned char
  Int16  // short
  UInt16 // unsigned short
  Int    // int
  UInt   // unsigned int
  Long   // long or long long
  ULong  // unsigned long or unsigned long long
  Float  // float
  Double // double
  Struct(Array[(String, CType)])
  Union(Array[(String, CType)])
  Enum(Array[String])
  Ptr(CType)
}

pub fn CType::void_() -> CType {
  CType::default_with(Void)
}

pub fn CType::char() -> CType {
  CType::default_with(Char)
}

pub fn CType::uchar() -> CType {
  CType::default_with(UChar)
}

pub fn CType::int16() -> CType {
  CType::default_with(Int16)
}

pub fn CType::uint16() -> CType {
  CType::default_with(UInt16)
}

pub fn CType::int() -> CType {
  CType::default_with(Int)
}

pub fn CType::uint() -> CType {
  CType::default_with(UInt)
}

pub fn CType::long() -> CType {
  CType::default_with(Long)
}

pub fn CType::ulong() -> CType {
  CType::default_with(ULong)
}

pub fn CType::float() -> CType {
  CType::default_with(Float)
}

pub fn CType::double() -> CType {
  CType::default_with(Double)
}
