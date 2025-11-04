///|
///
/// if tokens is empty (aka, []), it means it didn't come from 
/// source code.
pub(all) struct CType {
  dataKind : CTypeDataKind
  is_const : Bool
  is_volatile : Bool
  is_restrict : Bool
  is_atomic : Bool
  is_static : Bool
  is_thread_local : Bool
  is_extern : Bool
  tokens : ArrayView[Token]
}

///|
pub impl Eq for CType with equal(self, other) {
  self.dataKind == other.dataKind &&
  self.is_const == other.is_const &&
  self.is_volatile == other.is_volatile &&
  self.is_restrict == other.is_restrict &&
  self.is_atomic == other.is_atomic &&
  self.is_static == other.is_static &&
  self.is_thread_local == other.is_thread_local &&
  self.is_extern == other.is_extern
}

///|
fn CType::spec_to_string_first(self : CType) -> String {
  let sb = StringBuilder::new()
  if self.is_const {
    sb.write_string("const ")
  }
  if self.is_volatile {
    sb.write_string("volatile ")
  }
  if self.is_restrict {
    sb.write_string("restrict ")
  }
  if self.is_atomic {
    sb.write_string("_Atomic ")
  }
  if self.is_static {
    sb.write_string("static ")
  }
  if self.is_thread_local {
    sb.write_string("_Thread_local ")
  }
  if self.is_extern {
    sb.write_string("extern ")
  }
  sb.to_string()
}

///|
fn CType::spec_to_string_last(self : CType) -> String {
  let sb = StringBuilder::new()
  if self.is_const {
    sb.write_string(" const")
  }
  if self.is_volatile {
    sb.write_string(" volatile")
  }
  if self.is_restrict {
    sb.write_string(" restrict")
  }
  if self.is_atomic {
    sb.write_string(" _Atomic")
  }
  if self.is_static {
    sb.write_string(" static")
  }
  if self.is_thread_local {
    sb.write_string(" _Thread_local")
  }
  if self.is_extern {
    sb.write_string(" extern")
  }
  sb.to_string()
}

///|
pub impl Show for CType with output(self, logger) {
  let s = match self.dataKind {
    Ptr(_) => self.to_string(spec_first=false)
    _ => self.to_string(spec_first=true)
  }
  logger.write_string(s)
}

///|
fn CType::to_string(self : CType, spec_first~ : Bool) -> String {
  let sb = StringBuilder::new()
  if spec_first {
    sb.write_string(self.spec_to_string_first())
  }
  sb.write_object(self.dataKind)
  if !spec_first {
    sb.write_string(self.spec_to_string_last())
  }
  sb.to_string()
}

///|
pub fn CType::default_with(kind : CTypeDataKind) -> CType {
  return CType::{
    dataKind: kind,
    is_const: false,
    is_volatile: false,
    is_restrict: false,
    is_atomic: false,
    is_static: false,
    is_thread_local: false,
    is_extern: false,
    tokens: [],
  }
}

///|
pub fn CType::const_with(kind : CTypeDataKind) -> CType {
  return CType::{
    dataKind: kind,
    is_const: true,
    is_volatile: false,
    is_restrict: false,
    is_atomic: false,
    is_static: false,
    is_thread_local: false,
    is_extern: false,
    tokens: [],
  }
}

///|
pub(all) enum CTypeDataKind {
  Void // void
  Char // char
  UChar // unsigned char
  Int16 // short
  UInt16 // unsigned short
  Int // int
  UInt // unsigned int
  LongLong // long long
  Long // long
  ULong // unsigned long or unsigned long long
  ULongLong
  Float // float
  Double // double
  Struct(String, Array[(String, CType)])
  Union(String, Array[(String, CType)])
  Enum(String, Array[String])
  Ptr(CType)
} derive(Eq)

///|
pub impl Show for CTypeDataKind with output(self, logger) {
  fn fields_stringify(fields : Array[(String, CType)]) -> String {
    let sb = StringBuilder::new()
    sb.write_string("{ ")
    for field in fields {
      let (name, ctype) = field
      sb.write_object(ctype)
      sb.write_string(" ")
      sb.write_string(name)
      sb.write_string("; ")
    }
    sb.write_string("}")
    return sb.to_string()
  }

  let s = match self {
    Void => "void"
    Char => "char"
    UChar => "unsigned char"
    Int16 => "short"
    UInt16 => "unsigned short"
    Int => "int"
    UInt => "unsigned int"
    Long => "long"
    LongLong => "long long"
    ULong => "unsigned long"
    ULongLong => "unsigned long long"
    Float => "float"
    Double => "double"
    Struct("", fields) => {
      let sb = StringBuilder::new()
      sb.write_string("struct ")
      sb.write_string(fields_stringify(fields))
      sb.to_string()
    }
    Struct(name, _) => "struct \{name}"
    Union("", fields) => {
      let sb = StringBuilder::new()
      sb.write_string("union ")
      sb.write_string(fields_stringify(fields))
      sb.to_string()
    }
    Union(name, _) => "union \{name}"
    Enum("", variants) => {
      let sb = StringBuilder::new()
      sb.write_string("enum { ")
      for variant in variants {
        sb.write_string(variant)
        sb.write_string(", ")
      }
      sb.write_string("}")
      sb.to_string()
    }
    Enum(name, _) => "enum \{name}"
    Ptr(inner_ctype) => "\{inner_ctype} *"
  }
  logger.write_string(s)
}

///|
pub fn CType::void_() -> CType {
  CType::default_with(Void)
}

///|
pub fn CType::char() -> CType {
  CType::default_with(Char)
}

///|
pub fn CType::string() -> CType {
  let const_char = CType::const_with(Char)
  CType::default_with(Ptr(const_char))
}

///|
pub fn CType::uchar() -> CType {
  CType::default_with(UChar)
}

///|
pub fn CType::int16() -> CType {
  CType::default_with(Int16)
}

///|
pub fn CType::uint16() -> CType {
  CType::default_with(UInt16)
}

///|
pub fn CType::int() -> CType {
  CType::default_with(Int)
}

///|
pub fn CType::uint() -> CType {
  CType::default_with(UInt)
}

///|
pub fn CType::long() -> CType {
  CType::default_with(Long)
}

///|
pub fn CType::longlong() -> CType {
  CType::default_with(LongLong)
}

///|
pub fn CType::ulong() -> CType {
  CType::default_with(ULong)
}

///|
pub fn CType::ulonglong() -> CType {
  CType::default_with(ULongLong)
}

///|
pub fn CType::float() -> CType {
  CType::default_with(Float)
}

///|
pub fn CType::double() -> CType {
  CType::default_with(Double)
}

///|
pub fn CType::ptr_to(self : CType) -> CType {
  CType::default_with(Ptr(self))
}

///|
pub fn CType::struct_type(
  name : String,
  fields : Array[(String, CType)],
) -> CType {
  CType::default_with(Struct(name, fields))
}

///|
#alias(is_dec_ok)
pub fn CType::is_inc_ok(self : CType) -> Bool {
  match self.dataKind {
    Char => true
    UChar => true
    Int16 => true
    UInt16 => true
    Int => true
    UInt => true
    Long => true
    LongLong => true
    ULong => true
    ULongLong => true
    Ptr(_) => true
    _ => false
  }
}

///|
pub fn CType::is_numeric(self : CType) -> Bool {
  match self.dataKind {
    Char => true
    UChar => true
    Int16 => true
    UInt16 => true
    Int => true
    UInt => true
    Long => true
    LongLong => true
    ULong => true
    ULongLong => true
    Float => true
    Double => true
    _ => false
  }
}

///|
pub fn CType::is_integral(self : CType) -> Bool {
  match self.dataKind {
    Char => true
    UChar => true
    Int16 => true
    UInt16 => true
    Int => true
    UInt => true
    Long => true
    LongLong => true
    ULong => true
    ULongLong => true
    _ => false
  }
}

///|
pub fn CType::get_field_ctype_by_dot_acc(
  self : CType,
  field_name : String,
) -> CType? {
  let fields = match self.dataKind {
    Struct(_, fields) => fields
    Union(_, fields) => fields
    _ => return None
  }
  for field in fields {
    let (name, ctype) = field
    if name == field_name {
      return Some(ctype)
    }
  }
  None
}

///|
pub fn CType::get_field_ctype_by_ptr_acc(
  self : CType,
  field_name : String,
) -> CType? {
  guard self.dataKind is Ptr(inner_ctype) else { return None }
  inner_ctype.get_field_ctype_by_dot_acc(field_name)
}
