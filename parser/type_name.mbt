///|
#alias(parse_type_name)
pub fn Context::parse_ctype(
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
///
///
/// AI: Delete the notations after finishing the tests.
///
/// only test ctype without `*`, need more tests
test "Basic TypeName Parse Test" {
  let code =
    #|int ; const int ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup typenames
  let ctype_int = CType::int()
  ctx..add_typedef("MyInt", ctype_int)

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
  let (ty2, rest2) = ctx.parse_type_name(rest)
  inspect(ty2, content="const int")
  assert_true(
    ctx.parse_type_name(ty2.tokens) is (re_ty2, re_rest2) &&
    re_ty2 == ty2 &&
    re_rest2 is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest2)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "Basic TypeName Parse Error Test" {

}

///|
///
/// AI: Delete the notations after finishing the tests.
///
/// test typename with pointer `*`
/// e.g. `int *`, `const int *`, `int **`, `const int * const * volatile`
test "Pointer Type TypeName Parse Test" {

}

///|
test "Pointer Type TypeName Parse Error Test" {

}

///|
///
/// AI: Delete the notations after finishing the tests.
///
/// test typename with `[]`
/// e.g. `int []`, `const int [5]`, `int [static 10]`, `const int [static 20]`
///
/// note: `int[]` => `int *`, only `int [static N]` is array type
test "Array Type TypeName Parse Test" {

}

///|
test "Array Type TypeName Parse Error Test" {

}
