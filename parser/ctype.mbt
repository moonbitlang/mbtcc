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
  tokens : ArrayView[Token]
}

///|
pub impl Eq for CType with equal(self, other) {
  self.dataKind == other.dataKind &&
  self.is_const == other.is_const &&
  self.is_volatile == other.is_volatile &&
  self.is_restrict == other.is_restrict &&
  self.is_atomic == other.is_atomic
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
pub(all) enum CTypeDataKind {
  // void
  Void

  // char
  Char

  // unsigned char
  UChar

  // short
  Int16

  // unsigned short
  UInt16

  // int
  Int

  // unsigned int
  UInt

  // long
  Long

  // unsigned long
  ULong

  // long long
  LongLong

  // unsigned long long
  ULongLong

  // float
  Float

  // double
  Double

  // long double
  LongDouble
  Struct(String, Array[(String, CType)])
  Union(String, Array[(String, CType)])
  Enum(String, Array[String])
  Ptr(CType)
  Array(CType, Int)
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
    LongDouble => "long double"
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
    Array(inner_ctype, size) => "\{inner_ctype}[\{size}]"
  }
  logger.write_string(s)
}

///|
pub fn CType::default_with(kind : CTypeDataKind) -> CType {
  return CType::{
    dataKind: kind,
    is_const: false,
    is_volatile: false,
    is_restrict: false,
    is_atomic: false,
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
    tokens: [],
  }
}

///|
fn Context::parse_type_spec_qual_list(
  self : Self,
  tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = tokens.start_offset()
  let mut is_const = false
  let mut is_volatile = false
  let mut is_restrict = false
  let mut is_atomic = false
  let mut is_unsigned = false
  let mut is_signed = false
  let mut data_ty : CTypeDataKind? = None
  let rest = loop tokens {
    [{ kind: Keyword(Char), .. }, .. rest] => {
      data_ty = Some(Char)
      continue rest
    }
    [{ kind: Keyword(Int), .. }, .. rest] => {
      data_ty = Some(Int)
      continue rest
    }
    [{ kind: Keyword(Short), .. }, .. rest] => {
      data_ty = Some(Int16)
      continue rest
    }
    [{ kind: Keyword(Long), .. } as tok, .. rest] => {
      match data_ty {
        None => data_ty = Some(Long)
        Some(Int) => data_ty = Some(Long)
        Some(Long) => data_ty = Some(LongLong)
        Some(Double) => data_ty = Some(LongDouble)
        Some(LongLong) | Some(LongDouble) =>
          raise ParseError(tok, "Too many 'long' specifiers")
        Some(_) => {
          let msg = "'long' specifier cannot be combined with other type specifiers"
          raise ParseError(tok, msg)
        }
      }
      continue rest
    }
    [{ kind: Identifier(name), .. }, .. rest] if self.get_typename_ctype(name)
      is Some(ty) => {
      data_ty = Some(ty.dataKind)
      is_const = ty.is_const
      is_volatile = ty.is_volatile
      is_restrict = ty.is_restrict
      is_atomic = ty.is_atomic
      continue rest
    }
    [{ kind: Keyword(Signed), .. } as tok, .. rest] => {
      guard !is_unsigned else {
        raise ParseError(tok, "Conflicting signed/unsigned specifiers")
      }
      is_signed = true
      continue rest
    }
    [{ kind: Keyword(Unsigned), .. } as tok, .. rest] => {
      guard !is_signed else {
        raise ParseError(tok, "Conflicting signed/unsigned specifiers")
      }
      is_unsigned = true
      continue rest
    }
    [{ kind: Keyword(Const), .. } as tok, .. rest] => {
      guard !is_const else {
        raise ParseError(tok, "Duplicate 'const' qualifier")
      }
      is_const = true
      continue rest
    }
    [{ kind: Keyword(Volatile), .. } as tok, .. rest] => {
      guard !is_volatile else {
        raise ParseError(tok, "Duplicate 'volatile' qualifier")
      }
      is_volatile = true
      continue rest
    }
    [{ kind: Keyword(Restrict), .. } as tok, .. rest] => {
      guard !is_restrict else {
        raise ParseError(tok, "Duplicate 'restrict' qualifier")
      }
      is_restrict = true
      continue rest
    }
    [{ kind: Keyword(Atomic), .. } as tok, .. rest] => {
      guard !is_atomic else {
        raise ParseError(tok, "Duplicate '_Atomic' qualifier")
      }
      is_atomic = true
      continue rest
    }
    // struct, union, enum not implemented yet
    [{ kind: Keyword(Struct), .. } as tok, ..] =>
      raise ParseError(tok, "struct type specifier not implemented yet")
    [{ kind: Keyword(Union), .. } as tok, ..] =>
      raise ParseError(tok, "union type specifier not implemented yet")
    [{ kind: Keyword(Enum), .. } as tok, ..] =>
      raise ParseError(tok, "enum type specifier not implemented yet")
    tokens => break tokens
  }
  let dataKind = match data_ty {
    Some(ty) => ty
    None => {
      let msg = "Expected type specifier but found none"
      raise ParseError(tokens[0], msg)
    }
  }
  let tokens = init_tokens[0:rest.start_offset() - start_offset]
  let ctype = CType::{
    dataKind,
    is_const,
    is_volatile,
    is_restrict,
    is_atomic,
    tokens,
  }
  (ctype, rest)
}

///|
fn Context::parse_abstract_declarator(
  self : Self,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  let { dataKind, is_const, is_volatile, is_restrict, is_atomic, .. } = base_ty
  let start_offset = init_tokens.start_offset()
  let mut is_const = is_const
  let mut is_volatile = is_volatile
  let mut is_restrict = is_restrict
  let mut is_atomic = is_atomic
  let mut dataKind = dataKind
  fn reset_type_quals() {
    is_const = false
    is_volatile = false
    is_restrict = false
    is_atomic = false
  }

  // Parse Pointer
  let rest = loop tokens {
    [{ kind: Operator("*"), .. }, .. rest] => {
      let ctype = CType::{
        dataKind,
        is_const,
        is_volatile,
        is_restrict,
        is_atomic,
        tokens: init_tokens[0:rest.start_offset() - start_offset],
      }
      reset_type_quals()
      dataKind = Ptr(ctype)
      continue rest
    }
    [{ kind: Keyword(Const), .. } as tok, .. rest] => {
      guard !is_const else {
        raise ParseError(tok, "Duplicate 'const' qualifier")
      }
      is_const = true
      continue rest
    }
    [{ kind: Keyword(Volatile), .. } as tok, .. rest] => {
      guard !is_volatile else {
        raise ParseError(tok, "Duplicate 'volatile' qualifier")
      }
      is_volatile = true
      continue rest
    }
    [{ kind: Keyword(Restrict), .. } as tok, .. rest] => {
      guard !is_restrict else {
        raise ParseError(tok, "Duplicate 'restrict' qualifier")
      }
      is_restrict = true
      continue rest
    }
    [{ kind: Keyword(Atomic), .. } as tok, .. rest] => {
      guard !is_atomic else {
        raise ParseError(tok, "Duplicate '_Atomic' qualifier")
      }
      is_atomic = true
      continue rest
    }
    tokens => break tokens
  }
  let ctype = CType::{
    dataKind,
    is_const,
    is_volatile,
    is_restrict,
    is_atomic,
    tokens: init_tokens[0:rest.start_offset() - start_offset],
  }
  if rest is [{ kind: Bracket('[' | '('), .. }, ..] {
    self.parse_direct_abstract_declarator(rest, ctype, init_tokens)
  } else {
    (ctype, rest)
  }
}

///|
fn Context::parse_direct_abstract_declarator(
  self : Context,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Bracket('['), .. }, ..] =>
      self.parse_array_abstract_declarator(tokens, base_ty, init_tokens)
    [{ kind: Bracket('('), .. }, ..] =>
      self.parse_function_abstract_declarator(tokens, base_ty, init_tokens)
    tokens =>
      raise ParseError(tokens[0], "Expected '[' or '(' in abstract declarator")
  }
}

///|
fn Context::parse_array_abstract_declarator(
  self : Context,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('['), .. }, .. tokens]
  let start_offset = init_tokens.start_offset()
  let mut is_const = false
  let mut is_volatile = false
  let mut is_restrict = false
  let mut is_atomic = false
  // in C, decl like `int [5]`, the `5` inside the brackets is actully useless
  // `int [5]` <==> `int []` <==> `int *` ==> `Ptr(int)`
  // while `int [static 5]` is different, it means a static array
  // `int [static 5]` ==> `Array(int, 5)`
  // if `static` keyword is found inside the brackets, set is_static_array to true
  // the ctype is Array(base_ty, size), otherwise, ctype is Ptr(base_ty)
  let mut is_static_array = false
  let mut size : Int? = None
  let rest = loop tokens {
    [{ kind: Keyword(Static), .. } as tok, .. rest] => {
      guard !is_static_array else {
        raise ParseError(tok, "Duplicate 'static' keyword in array declarator")
      }
      is_static_array = true
      continue rest
    }
    [{ kind: Keyword(Const), .. } as tok, .. rest] => {
      guard !is_const else {
        raise ParseError(tok, "Duplicate 'const' qualifier in array declarator")
      }
      is_const = true
      continue rest
    }
    [{ kind: Keyword(Volatile), .. } as tok, .. rest] => {
      guard !is_volatile else {
        raise ParseError(
          tok, "Duplicate 'volatile' qualifier in array declarator",
        )
      }
      is_volatile = true
      continue rest
    }
    [{ kind: Keyword(Restrict), .. } as tok, .. rest] => {
      guard !is_restrict else {
        raise ParseError(
          tok, "Duplicate 'restrict' qualifier in array declarator",
        )
      }
      is_restrict = true
      continue rest
    }
    [{ kind: Keyword(Atomic), .. } as tok, .. rest] => {
      guard !is_atomic else {
        raise ParseError(
          tok, "Duplicate '_Atomic' qualifier in array declarator",
        )
      }
      is_atomic = true
      continue rest
    }
    [{ kind: Bracket(']'), .. }, .. rest] => break rest
    tokens => {
      let (const_expr, rest) = self.parse_constant_expr(tokens)
      size = Some(const_expr.eval_as_int())
      continue rest
    }
  }
  if is_static_array {
    guard size is Some(sz) else {
      raise ParseError(tokens[0], "Static array must have a size")
    }
    let ctype = CType::{
      dataKind: Array(base_ty, sz),
      is_const,
      is_volatile,
      is_restrict,
      is_atomic,
      tokens: init_tokens[0:rest.start_offset() - start_offset],
    }
    (ctype, rest)
  } else {
    let ctype = CType::{
      dataKind: Ptr(base_ty),
      is_const,
      is_volatile,
      is_restrict,
      is_atomic,
      tokens: init_tokens[0:rest.start_offset() - start_offset],
    }
    (ctype, rest)
  }
}

///|
fn Context::parse_function_abstract_declarator(
  self : Context,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  ignore(self)
  ignore(tokens)
  ignore(base_ty)
  ignore(init_tokens)
  // Not implemented yet
  raise ParseError(
    tokens[0],
    "Function abstract declarator not implemented yet",
  )
}

///|
pub fn Context::parse_type_name(
  self : Context,
  tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  let (base_ty, rest) = self.parse_type_spec_qual_list(tokens)
  if rest is [{ kind: Bracket('[' | '(') | Operator("*"), .. }, ..] {
    return self.parse_abstract_declarator(rest, base_ty, tokens)
  }
  (base_ty, rest)
}

///|
let void_ty : CType = CType::default_with(Void)

///|
let char_ty : CType = CType::default_with(Char)

///|
let uchar_ty : CType = CType::default_with(UChar)

///|
let int16_ty : CType = CType::default_with(Int16)

///|
let uint16_ty : CType = CType::default_with(UInt16)

///|
let int_ty : CType = CType::default_with(Int)

///|
let uint_ty : CType = CType::default_with(UInt)

///|
let long_ty : CType = CType::default_with(Long)

///|
let longlong_ty : CType = CType::default_with(LongLong)

///|
let ulong_ty : CType = CType::default_with(ULong)

///|
let ulonglong_ty : CType = CType::default_with(ULongLong)

///|
let string_ty : CType = CType::default_with(Ptr(CType::const_with(Char)))

///|
let float_ty : CType = CType::default_with(Float)

///|
let double_ty : CType = CType::default_with(Double)

///|
pub fn CType::void_() -> CType {
  void_ty
}

///|
pub fn CType::char() -> CType {
  char_ty
}

///|
pub fn CType::string() -> CType {
  string_ty
}

///|
pub fn CType::uchar() -> CType {
  uchar_ty
}

///|
pub fn CType::int16() -> CType {
  int16_ty
}

///|
pub fn CType::uint16() -> CType {
  uint16_ty
}

///|
pub fn CType::int() -> CType {
  int_ty
}

///|
pub fn CType::uint() -> CType {
  uint_ty
}

///|
pub fn CType::long() -> CType {
  long_ty
}

///|
pub fn CType::longlong() -> CType {
  longlong_ty
}

///|
pub fn CType::ulong() -> CType {
  ulong_ty
}

///|
pub fn CType::ulonglong() -> CType {
  ulonglong_ty
}

///|
pub fn CType::float() -> CType {
  float_ty
}

///|
pub fn CType::double() -> CType {
  double_ty
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
/// Check if the type is a scalar type.
/// Scalar types include arithmetic types (integers and floats) and pointer types.
/// This excludes void, struct, union, and enum types.
pub fn CType::is_scalar(self : CType) -> Bool {
  match self.dataKind {
    // Arithmetic types
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
    LongDouble => true
    // Pointer types
    Ptr(_) => true
    // Not scalar
    Void => false
    Struct(_, _) => false
    Union(_, _) => false
    Enum(_, _) => false
    Array(_, _) => false
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

///|
/// Find the common type of two types for arithmetic operations.
/// 
/// Returns the common type following C language type promotion rules,
/// or None if the types are incompatible for arithmetic operations.
///
/// ## Type Promotion Rules
///
/// 1. If either type is `double`, the result is `double`
/// 2. If either type is `float`, the result is `float`
/// 3. For integer types, the result is the type with higher rank:
///    - `long long` > `long` > `int` > `short` > `char`
///    - Unsigned and signed types of the same rank are compatible
///    - The result uses the higher rank, preferring unsigned if ranks are equal
/// 4. Types are incompatible if they include:
///    - `void`, `struct`, `union`, `enum`, or `pointer` types
///
/// ## Example
///
/// ```mbt
/// let int_type = CType::int()
/// let double_type = CType::double()
/// match int_type.common_type(double_type) {
///   Some({ dataKind: Double, ..}) => ()
///   Some(_) => fail("expected double type")
///   None => fail("types are incompatible")
/// }
/// ```
///
/// ## Returns
///
/// - `Some(CType)` - The common type for arithmetic operations
/// - `None` - If types are incompatible (e.g., struct, void, pointer)
pub fn CType::common_type(self : CType, other : CType) -> CType? {
  fn rank(kind : CTypeDataKind) -> Int? {
    match kind {
      Char => Some(1)
      UChar => Some(1)
      Int16 => Some(2)
      UInt16 => Some(2)
      Int => Some(3)
      UInt => Some(3)
      Long => Some(4)
      ULong => Some(4)
      LongLong => Some(5)
      ULongLong => Some(5)
      Float => Some(6)
      Double => Some(7)
      _ => None
    }
  }

  fn is_unsigned(kind : CTypeDataKind) -> Bool {
    match kind {
      UChar | UInt16 | UInt | ULong | ULongLong => true
      _ => false
    }
  }

  match (rank(self.dataKind), rank(other.dataKind)) {
    (None, _) | (_, None) => None
    (Some(r1), Some(r2)) => {
      // Double has highest precedence
      if r1 == 7 || r2 == 7 {
        return Some(CType::double())
      }
      // Float has second highest precedence
      if r1 == 6 || r2 == 6 {
        return Some(CType::float())
      }
      // For integer types, use the higher rank
      if r1 > r2 {
        Some(CType::default_with(self.dataKind))
      } else if r2 > r1 {
        Some(CType::default_with(other.dataKind))
        // Same rank, prefer unsigned
      } else if is_unsigned(self.dataKind) {
        Some(CType::default_with(self.dataKind))
      } else {
        Some(CType::default_with(other.dataKind))
      }
    }
  }
}

///|
/// Get the result type of additive operations (+ or -)
///
/// This function handles the type checking and result type determination
/// for addition and subtraction operations, including pointer arithmetic.
///
/// ## Rules for addition (+):
/// - pointer + integer => pointer
/// - integer + pointer => pointer
/// - numeric + numeric => common type
///
/// ## Rules for subtraction (-):
/// - pointer - integer => pointer
/// - pointer - pointer => ptrdiff_t (long)
/// - numeric - numeric => common type
///
/// Returns `None` if the operation is invalid.
pub fn CType::additive_result_type(
  self : CType,
  other : CType,
  op : String,
) -> CType? {
  match (self.dataKind, other.dataKind) {
    // pointer + integer => pointer (only for addition)
    (Ptr(_), _) if op is "+" && other.is_integral() => Some(self)
    // integer + pointer => pointer (only for addition)
    (_, Ptr(_)) if op is "+" && self.is_integral() => Some(other)
    // pointer - integer => pointer
    (Ptr(_), _) if op is "-" && other.is_integral() => Some(self)
    // pointer - pointer => ptrdiff_t (use long as ptrdiff_t)
    (Ptr(_), Ptr(_)) if op is "-" => Some(CType::long())
    // numeric op numeric => common type
    (_, _) if self.is_numeric() && other.is_numeric() => self.common_type(other)
    _ => None
  }
}

///|
test "Common Type Test" {
  // Test int and double -> double
  let int_type = CType::int()
  let double_type = CType::double()
  match int_type.common_type(double_type) {
    Some(result) => assert_true(result.dataKind == Double)
    None => fail("int and double should have common type")
  }

  // Test double and int -> double (commutative)
  match double_type.common_type(int_type) {
    Some(result) => assert_true(result.dataKind == Double)
    None => fail("double and int should have common type")
  }

  // Test int and float -> float
  let float_type = CType::float()
  match int_type.common_type(float_type) {
    Some(result) => assert_true(result.dataKind == Float)
    None => fail("int and float should have common type")
  }

  // Test float and double -> double
  match float_type.common_type(double_type) {
    Some(result) => assert_true(result.dataKind == Double)
    None => fail("float and double should have common type")
  }

  // Test int and int -> int
  match int_type.common_type(int_type) {
    Some(result) => assert_true(result.dataKind == Int)
    None => fail("int and int should have common type")
  }

  // Test int and long -> long
  let long_type = CType::long()
  match int_type.common_type(long_type) {
    Some(result) => assert_true(result.dataKind == Long)
    None => fail("int and long should have common type")
  }

  // Test char and int -> int
  let char_type = CType::char()
  match char_type.common_type(int_type) {
    Some(result) => assert_true(result.dataKind == Int)
    None => fail("char and int should have common type")
  }

  // Test unsigned int and int -> unsigned int (same rank, prefer unsigned)
  let uint_type = CType::uint()
  match int_type.common_type(uint_type) {
    Some(result) => assert_true(result.dataKind == UInt)
    None => fail("int and uint should have common type")
  }

  // Test long long and int -> long long
  let longlong_type = CType::longlong()
  match longlong_type.common_type(int_type) {
    Some(result) => assert_true(result.dataKind == LongLong)
    None => fail("long long and int should have common type")
  }

  // Test incompatible types: int and void -> None
  let void_type = CType::void_()
  match int_type.common_type(void_type) {
    Some(_) => fail("int and void should not have common type")
    None => ()
  }

  // Test incompatible types: int and pointer -> None
  let ptr_type = int_type.ptr_to()
  match int_type.common_type(ptr_type) {
    Some(_) => fail("int and pointer should not have common type")
    None => ()
  }

  // Test incompatible types: int and struct -> None
  let struct_type = CType::struct_type("Point", [
    ("x", int_type),
    ("y", int_type),
  ])
  match int_type.common_type(struct_type) {
    Some(_) => fail("int and struct should not have common type")
    None => ()
  }
}

///|
test "Additive Result Type Test" {
  let int_type = CType::int()
  let double_type = CType::double()
  let int_ptr = int_type.ptr_to()
  let int_ptr2 = int_type.ptr_to()

  // Test pointer + integer => pointer
  match int_ptr.additive_result_type(int_type, "+") {
    Some(result) => assert_true(result.dataKind is Ptr(_))
    None => fail("pointer + int should be valid")
  }

  // Test integer + pointer => pointer
  match int_type.additive_result_type(int_ptr, "+") {
    Some(result) => assert_true(result.dataKind is Ptr(_))
    None => fail("int + pointer should be valid")
  }

  // Test pointer - integer => pointer
  match int_ptr.additive_result_type(int_type, "-") {
    Some(result) => assert_true(result.dataKind is Ptr(_))
    None => fail("pointer - int should be valid")
  }

  // Test pointer - pointer => long (ptrdiff_t)
  match int_ptr.additive_result_type(int_ptr2, "-") {
    Some(result) => assert_true(result.dataKind == Long)
    None => fail("pointer - pointer should be valid")
  }

  // Test numeric + numeric => common type
  match int_type.additive_result_type(double_type, "+") {
    Some(result) => assert_true(result.dataKind == Double)
    None => fail("int + double should have common type")
  }

  // Test numeric - numeric => common type
  match double_type.additive_result_type(int_type, "-") {
    Some(result) => assert_true(result.dataKind == Double)
    None => fail("double - int should have common type")
  }

  // Test invalid: pointer + pointer
  match int_ptr.additive_result_type(int_ptr2, "+") {
    Some(_) => fail("pointer + pointer should be invalid")
    None => ()
  }

  // Test invalid: integer - pointer
  match int_type.additive_result_type(int_ptr, "-") {
    Some(_) => fail("int - pointer should be invalid")
    None => ()
  }

  // Test invalid: struct + int
  let point_fields = [("x", int_type), ("y", int_type)]
  let point_struct = CType::struct_type("Point", point_fields)
  match point_struct.additive_result_type(int_type, "+") {
    Some(_) => fail("struct + int should be invalid")
    None => ()
  }
}
