///|
/// Parse a type name from the given tokens.
///
/// Type names are used in cast expressions, sizeof/alignof expressions,
/// and other contexts where a type is specified without a variable name.
///
/// Returns a tuple containing the parsed CType and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// int                     // Basic integer type
/// const int               // Const qualified integer
/// unsigned long           // Unsigned long type
/// int *                   // Pointer to int
/// const int *             // Pointer to const int
/// int * const             // Const pointer to int
/// int **                  // Pointer to pointer to int
/// int [10]                // Array (treated as pointer)
/// int [static 10]         // Static array of 10 integers
/// const int [static 5]    // Static array of const integers
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "int *"
/// let ctx = Context::new(code~, source_file="demo")
/// let (ctype, rest) = ctx.parse_type_name(ctx.tokens)
/// inspect(
///   ctype,
///   content="int *"
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. No type specifier is found.
///
///    e.g.,
///    
///    ```c
///    *      // missing type specifier before '*'
///    ```
///
/// 2. Duplicate type qualifiers are specified.
///
///    e.g.,
///
///    ```c
///    const const int    // duplicate 'const' qualifier
///    ```
///
/// 3. Conflicting type specifiers.
///
///    e.g.,
///
///    ```c
///    signed unsigned int    // conflicting signed/unsigned
///    ```
///
/// 4. Function type abstract declarators (not yet implemented).
///
///    e.g.,
///
///    ```c
///    int (int, int)    // function type not supported yet
///    ```
///
/// 5. Struct/union/enum types (not yet implemented).
///
///    e.g.,
///
///    ```c
///    struct Point    // struct not supported yet
///    ```
#alias(parse_type_name)
pub fn Context::parse_ctype(
  self : Context,
  tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  let (base_ty, _, rest) = self.parse_decl_spec(tokens)
  self.parse_abstract_declarator(rest, base_ty, tokens)
}

///|
fn Context::parse_pointers(
  _ : Context,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  let start_offset = init_tokens.start_offset()
  let mut is_const = base_ty.is_const
  let mut is_volatile = base_ty.is_volatile
  let mut is_restrict = base_ty.is_restrict
  let mut is_atomic = base_ty.is_atomic
  let mut dataKind = base_ty.dataKind
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
      is_const = false
      is_volatile = false
      is_restrict = false
      is_atomic = false
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
  (ctype, rest)
}

///|
fn Context::parse_abstract_declarator(
  self : Self,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  let (ty, rest) = self.parse_pointers(tokens, base_ty, init_tokens)
  if rest is [{ kind: Bracket('('), .. }, tok, ..] &&
    !self.is_keyword_or_type_name(tok) {
    let rest2 = rest[1:]
    let dummy_base_ty = CType::void_()
    let (_, rest) = self.parse_abstract_declarator(
      rest2, dummy_base_ty, init_tokens,
    )
    guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
      raise ParseError(rest[0], "Expected ')' to close abstract declarator")
    }
    let (new_base_ty, rest) = self.parse_type_suffix(rest, ty, init_tokens)
    let (ctype, _) = self.parse_abstract_declarator(
      rest2, new_base_ty, init_tokens,
    )
    let tokens = init_tokens[0:rest.start_offset() - init_tokens.start_offset()]
    ctype.tokens = tokens
    return (ctype, rest)
  }
  self.parse_type_suffix(rest, ty, init_tokens)
}

///|
fn Context::parse_type_suffix(
  self : Context,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Bracket('['), .. }, ..] =>
      self.parse_array_abstract_declarator(tokens, base_ty, init_tokens)
    [{ kind: Bracket('('), .. }, ..] =>
      self.parse_function_declarator(tokens, base_ty, init_tokens)
    tokens => (base_ty, tokens)
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
      let (const_expr, rest) = self.parse_conditional_expr(tokens)
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
fn Context::parse_function_declarator(
  self : Context,
  tokens : ArrayView[Token],
  base_ty : CType,
  init_tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    println("Compile ICE: Expected '(' in function declarator")
    panic()
  }
  if tokens
    is [{ kind: Keyword(Void), .. }, { kind: Bracket(')'), .. }, .. rest] {
    // function with no parameters
    let start_offset = init_tokens.start_offset()
    let tokens = init_tokens[0:rest.start_offset() - start_offset]
    let is_const = false
    let is_volatile = false
    let is_restrict = false
    let is_atomic = false
    let dataKind = Function(Array::new(), base_ty, is_variadic=false)
    let ctype = CType::{
      dataKind,
      is_const,
      is_volatile,
      is_restrict,
      is_atomic,
      tokens,
    }
    return (ctype, rest)
  }
  let parameter_types : Array[(CType, String)] = Array::new()
  let mut is_variadic = false
  let rest = loop tokens {
    [
      { kind: Comma, .. },
      { kind: Ellipsis, .. },
      { kind: Bracket(')'), .. },
      .. rest,
    ] => {
      is_variadic = true
      break rest
    }
    [{ kind: Ellipsis, .. }, { kind: Bracket(')'), .. }, .. rest] => {
      is_variadic = true
      break rest
    }
    [{ kind: Ellipsis, .. }, tok, ..] => {
      let msg = "Expected ')' after '...' in function parameter list"
      raise ParseError(tok, msg)
    }
    [{ kind: Bracket(')'), .. }, .. rest] => break rest
    [{ kind: Comma, .. }, { kind: Bracket(')'), .. }, .. rest] => break rest
    [{ kind: Comma, .. }, tok, ..] as tokens if self.is_keyword_or_type_name(
        tok,
      ) => continue tokens[1:]
    [{ kind: Comma, .. }, tok, ..] => {
      let msg = "Unexpected token '\{tok}' in function parameter list"
      raise ParseError(tok, msg)
    }
    [tok, ..] as tokens if self.is_keyword_or_type_name(tok) => {
      let (param_ty, storage, rest) = self.parse_decl_spec(tokens)
      let (param_ty, param_name, rest) = self.parse_declarator(
        param_ty, storage, rest, init_tokens,
      )
      parameter_types.push((param_ty, param_name))
      continue rest
    }
    [] => {
      let msg = "Unexpected end of tokens in function parameter list"
      raise ParseError(init_tokens[0], msg)
    }
    [tok, ..] => {
      let msg = "Unexpected token in function parameter list"
      raise ParseError(tok, msg)
    }
  }
  let start_offset = init_tokens.start_offset()
  let tokens = init_tokens[0:rest.start_offset() - start_offset]
  let is_const = false
  let is_volatile = false
  let is_restrict = false
  let is_atomic = false
  let dataKind = Function(parameter_types, base_ty, is_variadic~)
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
fn Context::parse_decl_spec(
  self : Self,
  tokens : ArrayView[Token],
) -> (CType, StorageClass, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = tokens.start_offset()
  let mut is_const = false
  let mut is_volatile = false
  let mut is_restrict = false
  let mut is_atomic = false
  let mut is_unsigned = false
  let mut is_signed = false
  let mut is_static = false
  let mut is_extern = false
  let mut is_thread_local = false
  let mut is_register = false
  let mut is_auto = false
  let mut data_ty : CTypeDataKind? = None
  let rest = loop tokens {
    [{ kind: Keyword(Void), .. }, .. rest] => {
      data_ty = Some(Void)
      continue rest
    }
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
    [{ kind: Keyword(Float), .. }, .. rest] => {
      data_ty = Some(Float)
      continue rest
    }
    [{ kind: Keyword(Double), .. }, .. rest] => {
      data_ty = Some(Double)
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
    [{ kind: Keyword(Static), .. } as tok, .. rest] => {
      guard !is_static else {
        raise ParseError(tok, "Duplicate 'static' storage class specifier")
      }
      guard !is_auto else {
        raise ParseError(
          tok, "'static' and 'auto' storage class specifiers are mutually exclusive",
        )
      }
      is_static = true
      continue rest
    }
    [{ kind: Keyword(Extern), .. } as tok, .. rest] => {
      guard !is_extern else {
        raise ParseError(tok, "Duplicate 'extern' storage class specifier")
      }
      guard !is_auto else {
        raise ParseError(
          tok, "'extern' and 'auto' storage class specifiers are mutually exclusive",
        )
      }
      is_extern = true
      continue rest
    }
    [{ kind: Keyword(ThreadLocal), .. } as tok, .. rest] => {
      guard !is_thread_local else {
        raise ParseError(
          tok, "Duplicate '_Thread_local' storage class specifier",
        )
      }
      guard !is_auto else {
        raise ParseError(
          tok, "'_Thread_local' and 'auto' storage class specifiers are mutually exclusive",
        )
      }
      is_thread_local = true
      continue rest
    }
    [{ kind: Keyword(Register), .. } as tok, .. rest] => {
      guard !is_register else {
        raise ParseError(tok, "Duplicate 'register' storage class specifier")
      }
      guard !is_auto else {
        raise ParseError(
          tok, "'register' and 'auto' storage class specifiers are mutually exclusive",
        )
      }
      is_register = true
      continue rest
    }
    [{ kind: Keyword(Auto), .. } as tok, .. rest] => {
      guard !is_auto else {
        raise ParseError(tok, "Duplicate 'auto' storage class specifier")
      }
      is_auto = true
      continue rest
    }
    // struct, union, enum not implemented yet
    [{ kind: Keyword(Struct), .. } as tok, ..] =>
      raise ParseError(tok, "struct type specifier not implemented yet")
    [{ kind: Keyword(Union), .. } as tok, ..] =>
      raise ParseError(tok, "union type specifier not implemented yet")
    [{ kind: Keyword(Enum), .. }, ..] as tokens => {
      let (ty, rest) = self.parse_enum_specifier(tokens)
      let storage_class = StorageClass::{
        is_static,
        is_extern,
        is_thread_local,
        is_register,
      }
      return (ty, storage_class, rest)
    }
    tokens => break tokens
  }
  let base_kind = match data_ty {
    Some(ty) => ty
    None =>
      // If no explicit type, default to 'int' only if unsigned/signed is specified
      if is_unsigned || is_signed {
        Int
      } else {
        let msg = "Expected type specifier but found none"
        raise ParseError(tokens[0], msg)
      }
  }
  let storage_class = StorageClass::{
    is_static,
    is_extern,
    is_thread_local,
    is_register,
  }
  // Apply unsigned/signed modifier
  let dataKind = if is_unsigned {
    match base_kind {
      Char => UChar
      Int16 => UInt16
      Int => UInt
      Long => ULong
      LongLong => ULongLong
      _ => base_kind
    }
  } else {
    base_kind
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
  (ctype, storage_class, rest)
}

///|
pub fn Context::parse_enum_specifier(
  self : Context,
  tokens : ArrayView[Token],
) -> (CType, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Enum), .. } as enum_kw_tok, .. tokens] else {
    println("Compile ICE: Expected 'enum' keyword in enum specifier")
    panic()
  }
  let (enum_name, tokens) = if tokens
    is [{ kind: Identifier(name), .. }, .. rest] {
    guard !self.is_name_has_been_defined(name) else {
      raise ParseError(rest[0], "Enum name '\{name}' has already been defined")
    }
    (name, rest)
  } else {
    ("", tokens)
  }
  let variants : Array[(String, Int)] = Array::new()
  let dataKind = CTypeDataKind::Enum(enum_name, variants)
  let ctype = CType::{
    dataKind,
    is_const: false,
    is_volatile: false,
    is_restrict: false,
    is_atomic: false,
    tokens: Array::new(),
  }
  guard tokens is [{ kind: Bracket('{'), .. }, .. tokens] else {
    return (ctype, tokens)
  }
  let mut value = 0
  let rest = loop tokens {
    [{ kind: Identifier(vari), .. }, .. rest] if !self.is_name_has_been_defined(
        vari,
      ) => {
      let rest = if rest is [{ kind: AssignOp("="), .. }, .. rest] {
        let (const_expr, rest) = self.parse_constant_expr(rest)
        value = const_expr.eval_as_int()
        rest
      } else {
        rest
      }
      variants.push((vari, value))
      self.add_enum_member(vari, ctype, value)
      value = value + 1
      continue rest
    }
    [{ kind: Identifier(vari), .. } as tok, ..] => {
      let msg = match self.defined.get(vari).unwrap() {
        EnumMember(ty, i) =>
          "Enum variant name '\{vari}' has already been defined as enum member '\{ty}' with value \{i}"
        TypeDef(_) =>
          "Enum variant name '\{vari}' has already been defined as typedef"
        Variable(_) =>
          "Enum variant name '\{vari}' has already been defined as variable"
        Label => "Enum variant name '\{vari}' has already been defined as label"
      }
      raise ParseError(tok, msg)
    }
    [{ kind: Comma, .. }, { kind: Identifier(_) | Bracket('}'), .. }, ..] as tokens =>
      continue tokens[1:]
    [{ kind: Comma, .. }, tok, ..] => {
      let msg = "Unexpected token '\{tok}' in enum variant list"
      raise ParseError(tok, msg)
    }
    [{ kind: Bracket('}'), .. }, .. rest] => break rest
    [] => {
      let msg = "Unexpected end of tokens in enum variant list"
      raise ParseError(enum_kw_tok, msg)
    }
    [tok, ..] => {
      let msg = "Unexpected token '\{tok}' in enum variant list"
      raise ParseError(tok, msg)
    }
  }
  (ctype, rest)
}

///|
test "Basic TypeName Parse Test" {
  let code =
    #|int ; const int ; unsigned long ; volatile char ;
    #|long long ; short ; unsigned int ; const volatile int ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup typenames
  let ctype_int = CType::int()
  ctx.add_typedef("MyInt", ctype_int)

  // Parse `int`
  let (ty, rest) = ctx.parse_type_name(ctx.tokens)
  inspect(ty, content="int")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const int`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const int")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `unsigned long`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="unsigned long")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `volatile char`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="volatile char")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `long long`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="long long")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `short`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="short")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `unsigned int`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="unsigned int")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const volatile int`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const volatile int")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Basic TypeName Parse Error Test" {
  // Error test: duplicate const qualifier
  let code_err1 = "const const int"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_type_name(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: conflicting signed/unsigned specifiers
  let code_err2 = "signed unsigned int"
  let ctx_err2 = Context::new(code=code_err2)
  let r = try? ctx_err2.parse_type_name(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: duplicate volatile qualifier
  let code_err3 = "volatile volatile int"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_type_name(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: no type specifier
  let code_err4 = "const"
  let ctx_err4 = Context::new(code=code_err4)
  let r = try? ctx_err4.parse_type_name(ctx_err4.tokens)
  assert_true(r is Err(_))
}

///|
test "Pointer Type TypeName Parse Test" {
  let code =
    #|int * ; const int * ; int ** ; int * const ;
    #|const int * const ; int * volatile ; const int * const * volatile ;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int *`
  let (ty, rest) = ctx.parse_type_name(ctx.tokens)
  inspect(ty, content="int *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const int *`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const int *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `int **`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="int * *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `int * const`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="int * const")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const int * const`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const int * const")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `int * volatile`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="int * volatile")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const int * const * volatile`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const int * const * volatile")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Pointer Type TypeName Parse Error Test" {
  // Error test: duplicate const qualifier on pointer
  let code_err1 = "int * const const"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_type_name(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: duplicate volatile qualifier on pointer
  let code_err2 = "int * volatile volatile"
  let ctx_err2 = Context::new(code=code_err2)
  let r = try? ctx_err2.parse_type_name(ctx_err2.tokens)
  assert_true(r is Err(_))
}

///|
test "Array Type TypeName Parse Test" {
  let code =
    #|int [] ; const int [5] ; int [static 10] ; const int [static 20] ;
    #|int [static 100] ; volatile int [] ;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int []` => `int *`
  let (ty, rest) = ctx.parse_type_name(ctx.tokens)
  inspect(ty, content="int *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const int [5]` => `const int *`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const int *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `int [static 10]` => `int[static 10]`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="int[static 10]")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `const int [static 20]` => `const int[static 20]`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="const int[static 20]")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `int [static 100]`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="int[static 100]")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `volatile int []` => `volatile int *`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="volatile int *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Array Type TypeName Parse Error Test" {
  // Error test: static array without size
  let code_err1 = "int [static]"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_type_name(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: duplicate static keyword
  let code_err2 = "int [static static 10]"
  let ctx_err2 = Context::new(code=code_err2)
  let r = try? ctx_err2.parse_type_name(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: duplicate const in array declarator
  let code_err3 = "int [const const 10]"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_type_name(ctx_err3.tokens)
  assert_true(r is Err(_))
}

///|
test "Function Type TypeName Parse Test" {
  let code =
    #|int (int, int) ; void (float, double, ...) ;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int (int, int)`
  let (ty, rest) = ctx.parse_type_name(ctx.tokens)
  inspect(ty, content="int (int, int)")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `void (float, double, ...)`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="void (float, double, ...)")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Function Type TypeName Parse Error Test" {
  // Error test: function type without closing parenthesis
  let code_err1 = "int (int, float"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_type_name(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: unexpected token in parameter list
  let code_err2 = "void (int, $, float)"
  let ctx_err2 = Context::new(code=code_err2)
  let r = try? ctx_err2.parse_type_name(ctx_err2.tokens)
  assert_true(r is Err(_))
}

///|
test "Function Pointer Type TypeName Parse Test" {
  let code =
    #|int (*)(int, int) ; void (*)(float, double, ...) ;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `int (*) (int, int)`
  let (ty, rest) = ctx.parse_type_name(ctx.tokens)
  inspect(ty, content="int (int, int) *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // Parse `void (*) (float, double, ...)`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="void (float, double, ...) *")
  assert_true(
    ctx.parse_type_name(ty.tokens) is (re_ty, re_rest) &&
    re_ty == ty &&
    re_rest is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Enum Type Parsing Test" {
  let code =
    #|enum Color { Red, Green, Blue } ;
    #|enum { A, B, C } ;
    #|enum Status { OK = 0, ERROR = -1, PENDING } ;
    #|enum Values { X = 10, Y, Z = 20, W } ;
    #|enum Direction ;
    #|enum { First = 1, Second, Third, Fourth = 100, Fifth } ;
  let ctx = Context::new(code~, source_file="demo")

  // Parse `enum Color { Red, Green, Blue }`
  let (ty, rest) = ctx.parse_type_name(ctx.tokens)
  inspect(ty, content="enum Color")
  guard ty.dataKind is Enum(name, variants) else { fail("Expected Enum type") }
  inspect(name, content="Color")
  inspect(variants.length(), content="3")
  inspect(variants[0], content="(\"Red\", 0)")
  inspect(variants[1], content="(\"Green\", 1)")
  inspect(variants[2], content="(\"Blue\", 2)")
  assert_true(ctx.is_enum_member("Red"))
  assert_true(ctx.is_enum_member("Green"))
  assert_true(ctx.is_enum_member("Blue"))

  // Parse `enum { A, B, C }` - anonymous enum
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="enum { A = 0, B = 1, C = 2, }")
  guard ty.dataKind is Enum(name, variants) else { fail("Expected Enum type") }
  inspect(name, content="")
  inspect(variants.length(), content="3")
  inspect(variants[0], content="(\"A\", 0)")
  inspect(variants[1], content="(\"B\", 1)")
  inspect(variants[2], content="(\"C\", 2)")
  assert_true(ctx.is_enum_member("A"))
  assert_true(ctx.is_enum_member("B"))
  assert_true(ctx.is_enum_member("C"))

  // Parse `enum Status { OK = 0, ERROR = -1, PENDING }` - with explicit values
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="enum Status")
  guard ty.dataKind is Enum(name, variants) else { fail("Expected Enum type") }
  inspect(name, content="Status")
  inspect(variants.length(), content="3")
  inspect(variants[0], content="(\"OK\", 0)")
  inspect(variants[1], content="(\"ERROR\", -1)")
  // PENDING should be ERROR + 1 = -1 + 1 = 0
  inspect(variants[2], content="(\"PENDING\", 0)")
  assert_true(ctx.is_enum_member("OK"))
  assert_true(ctx.is_enum_member("ERROR"))
  assert_true(ctx.is_enum_member("PENDING"))

  // Parse `enum Values { X = 10, Y, Z = 20, W }` - mixed explicit and implicit
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="enum Values")
  guard ty.dataKind is Enum(name, variants) else { fail("Expected Enum type") }
  inspect(name, content="Values")
  inspect(variants.length(), content="4")
  inspect(variants[0], content="(\"X\", 10)")
  inspect(variants[1], content="(\"Y\", 11)")
  inspect(variants[2], content="(\"Z\", 20)")
  inspect(variants[3], content="(\"W\", 21)")

  // Parse `enum Direction` - forward declaration without body
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(ty, content="enum Direction")
  guard ty.dataKind is Enum(name, variants) else { fail("Expected Enum type") }
  inspect(name, content="Direction")
  inspect(variants.length(), content="0")

  // Parse `enum { First = 1, Second, Third, Fourth = 100, Fifth }`
  let rest = next_check_point(rest)
  let (ty, rest) = ctx.parse_type_name(rest)
  inspect(
    ty,
    content="enum { First = 1, Second = 2, Third = 3, Fourth = 100, Fifth = 101, }",
  )
  assert_true(ty.dataKind is Enum("", _))
  guard ty.dataKind is Enum(name, variants) else { fail("Expected Enum type") }
  inspect(name, content="")
  inspect(variants.length(), content="5")
  inspect(variants[0], content="(\"First\", 1)")
  inspect(variants[1], content="(\"Second\", 2)")
  inspect(variants[2], content="(\"Third\", 3)")
  inspect(variants[3], content="(\"Fourth\", 100)")
  inspect(variants[4], content="(\"Fifth\", 101)")

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Enum Type Parsing Error Test" {
  // Error test: enum name already defined as typedef
  let code_err1 = "typedef int MyType; enum MyType { A, B }"
  let ctx_err1 = Context::new(code=code_err1)
  let (_, rest) = ctx_err1.parse_declaration(ctx_err1.tokens)
  let r = try? ctx_err1.parse_type_name(rest)
  assert_true(r is Err(_))

  // Error test: enum name already defined as variable
  let code_err2 = "int x; enum x { A, B }"
  let ctx_err2 = Context::new(code=code_err2)
  let (_, rest) = ctx_err2.parse_declaration(ctx_err2.tokens)
  let r = try? ctx_err2.parse_type_name(rest)
  assert_true(r is Err(_))

  // Error test: enum variant name already defined as enum member
  let code_err3 = "enum { A, B, A }"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_type_name(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: enum variant name already defined as typedef
  let code_err4 = "typedef int MyInt; enum { MyInt, B }"
  let ctx_err4 = Context::new(code=code_err4)
  let (_, rest) = ctx_err4.parse_declaration(ctx_err4.tokens)
  let r = try? ctx_err4.parse_type_name(rest)
  assert_true(r is Err(_))

  // Error test: enum variant name already defined as variable
  let code_err5 = "int var; enum { var, B }"
  let ctx_err5 = Context::new(code=code_err5)
  let (_, rest) = ctx_err5.parse_declaration(ctx_err5.tokens)
  let r = try? ctx_err5.parse_type_name(rest)
  assert_true(r is Err(_))

  // Error test: unexpected end of tokens in enum variant list
  let code_err6 = "enum { A, B"
  let ctx_err6 = Context::new(code=code_err6)
  let r = try? ctx_err6.parse_type_name(ctx_err6.tokens)
  assert_true(r is Err(_))

  // Error test: unexpected token in enum variant list
  let code_err7 = "enum { A, ?, B }"
  let ctx_err7 = Context::new(code=code_err7)
  let r = try? ctx_err7.parse_type_name(ctx_err7.tokens)
  assert_true(r is Err(_))

  // Error test: unexpected token after comma in enum variant list
  let code_err8 = "enum { A, , B }"
  let ctx_err8 = Context::new(code=code_err8)
  let r = try? ctx_err8.parse_type_name(ctx_err8.tokens)
  assert_true(r is Err(_))

  // Error test: enum with only commas
  let code_err9 = "enum { , , }"
  let ctx_err9 = Context::new(code=code_err9)
  let r = try? ctx_err9.parse_type_name(ctx_err9.tokens)
  assert_true(r is Err(_))

  // Error test: enum variant with invalid assignment expression
  let code_err10 = "enum { A = x, B }"
  let ctx_err10 = Context::new(code=code_err10)
  let r = try? ctx_err10.parse_type_name(ctx_err10.tokens)
  assert_true(r is Err(_))

  // Error test: trailing comma with unexpected token
  let code_err11 = "enum { A, B, }"
  let ctx_err11 = Context::new(code=code_err11)
  let r = try? ctx_err11.parse_type_name(ctx_err11.tokens)
  // Trailing comma should be allowed and skip to closing brace
  assert_true(r is Ok(_))
}
