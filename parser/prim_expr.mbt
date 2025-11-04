///|
///
/// PrimExpr: Primary Expression
///
/// PrimExpr represents primary expressions such as literals and identifiers.
///
/// ## Examples
///
/// ```c
/// 1 => int literal
/// 2l => long literal
/// 3u => unsigned int literal
/// 4ul => unsigned long literal
/// 5ull => unsigned long long literal
/// 6L => long literal
/// 7U => unsigned int literal
/// 8UL => unsigned long literal
/// 9ll => long long literal
/// 9.5 => double literal
/// 10.0f => float literal
/// 'c' => char literal
/// "hello" => string literal
/// x => variable identifier if the context defines `x` as a variable
/// ```
///
/// ## Grammar (EBNF)
///
/// PrimExpr ::=
///     Ident    // Variable identifier
///   | Int      // Integer literal
///   | Long     // Long integer literal
///   | LongLong // Long long integer literal
///   | UInt     // Unsigned integer literal
///   | ULong    // Unsigned long integer literal
///   | ULongLong // Unsigned long long integer literal
///   | Float    // Float literal
///   | Double   // Double literal
///   | Char     // Character literal
///   | Strings  // String literal(s)
///   | '(' Expr ')' // Parenthesized expression (TODO)
///   ;
pub struct PrimExpr {
  kind : PrimExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Show for PrimExpr with output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub impl Eq for PrimExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub fn PrimExpr::to_string(
  self : Self,
  color? : Bool = true,
  indent? : Int = 0,
) -> String {
  let prefix = match self.kind {
    Ident(_) => "variable"
    Char(_) => "char literal"
    Int(_) => "int literal"
    Long(_) => "long literal"
    LongLong(_) => "long long literal"
    UInt(_) => "unsigned int literal"
    ULong(_) => "unsigned long literal"
    ULongLong(_) => "unsigned long long literal"
    Float(_) => "float literal"
    Double(_) => "double literal"
    Strings(_) => "string literal"
  }
  let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
  let ctype = if color {
    @color.taint("(\{self.ctype})", Green)
  } else {
    "(\{self.ctype})"
  }
  " ".repeat(indent) + "\{prefix} \{self.kind} \{ctype}"
}

///|
pub enum PrimExprKind {
  Ident(String)
  Char(Char)
  Int(Int)
  Long(Int64)
  LongLong(Int64)
  UInt(UInt)
  ULong(UInt64)
  ULongLong(UInt64)
  Float(Float)
  Double(Double)
  Strings(Array[String])
  // Paren(Expr) // TODO
} derive(Eq)

///|
pub impl Show for PrimExprKind with output(self, logger) {
  let s = match self {
    Ident(name) => "\{name}"
    Char(c) => "'\{c}'"
    Int(v) => "\{v}"
    Long(v) => "\{v}l"
    LongLong(v) => "\{v}ll"
    UInt(v) => "\{v}u"
    ULong(v) => "\{v}ul"
    ULongLong(v) => "\{v}ull"
    Float(v) => "\{v}f"
    Double(v) => "\{v}"
    Strings(strs) => {
      let joined = strs.join("")
      "\"\{joined}\""
    }
  }
  logger.write_string(s)
}

///|
pub fn Context::parse_prim_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (PrimExpr, ArrayView[Token]) raise ParseError {
  let start_offset = tokens.start_offset()
  let (prim_expr_kind, rest_toks) = match tokens {
    [{ kind: Int(v), .. }, .. rest] => (PrimExprKind::Int(v), rest)
    [{ kind: Long(v), .. }, .. rest] => (Long(v), rest)
    [{ kind: LongLong(v), .. }, .. rest] => (LongLong(v), rest)
    [{ kind: UInt(v), .. }, .. rest] => (UInt(v), rest)
    [{ kind: ULong(v), .. }, .. rest] => (ULong(v), rest)
    [{ kind: ULongLong(v), .. }, .. rest] => (ULongLong(v), rest)
    [{ kind: Float(v), .. }, .. rest] => (Float(v), rest)
    [{ kind: Double(v), .. }, .. rest] => (Double(v), rest)
    [{ kind: Char(c), .. }, .. rest] => (Char(c), rest)
    [{ kind: Identifier(name), .. }, .. rest] if self.is_var_name(name) =>
      (Ident(name), rest)
    [{ kind: Identifier(name), .. }, ..] => {
      let msg = "Identifier '\{name}' is not defined as a variable"
      raise ParseError(tokens[0], msg)
    }
    [{ kind: String(_), .. }, ..] as tokens => {
      let strs : Array[String] = Array::new()
      let rest_tokens = loop tokens {
        [{ kind: String(s), .. }, .. rest] => {
          strs.push(s)
          continue rest
        }
        rest => break rest
      }
      (Strings(strs), rest_tokens)
    }
    tokens => raise ParseError(tokens[0], "Expected a primary expression")
  }
  let end_offset = rest_toks.start_offset()
  let offset_range = end_offset - start_offset
  let tok_view = tokens[0:offset_range]
  let ctype = self.get_literal_ctype(prim_expr_kind)
  let prim_expr = PrimExpr::{ kind: prim_expr_kind, ctype, tokens: tok_view }
  (prim_expr, rest_toks)
}

///|
fn Context::get_literal_ctype(self : Context, kind : PrimExprKind) -> CType {
  match kind {
    Int(_) => CType::int()
    Long(_) => CType::long()
    LongLong(_) => CType::longlong()
    UInt(_) => CType::uint()
    ULong(_) => CType::ulong()
    ULongLong(_) => CType::ulonglong()
    Float(_) => CType::float()
    Double(_) => CType::double()
    Char(_) => CType::char()
    Strings(_) => CType::string()
    Ident(name) => self.get_var_ctype(name).unwrap() // safe unwrap
  }
}

///|
test "PrimExpr Parse Test" {
  let color = false
  let code =
    #|1 ; 2l ; 3u ; 4ul ; 5ull ; 6L ; 7U ; 8UL ; 9ll ; 9.5 ; 10.0f ;
    #|'c' ; "hello" ; x ; "hello" " world" ; Integer ; ?
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())
  ctx.add_typedef("Integer", CType::int())

  // Parse `1`
  let (prim_expr, rest) = ctx.parse_prim_expr(ctx.tokens)
  inspect(prim_expr.to_string(color~), content="int literal 1 (int)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `2l`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.to_string(color~), content="long literal 2l (long)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `3u`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content="unsigned int literal 3u (unsigned int)",
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `4ul`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content="unsigned long literal 4ul (unsigned long)",
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `5ull`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content="unsigned long long literal 5ull (unsigned long long)",
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `6L`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.to_string(color~), content="long literal 6l (long)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `7U`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content="unsigned int literal 7u (unsigned int)",
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `8UL`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content="unsigned long literal 8ul (unsigned long)",
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `9ll`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content="long long literal 9ll (long long)",
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `9.5`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.to_string(color~), content="double literal 9.5 (double)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `10.0f`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.to_string(color~), content="float literal 10f (float)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `'c'`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.to_string(color~), content="char literal 'c' (char)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `"hello"`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content=(
      #|string literal "hello" (const char *)
    ),
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `x`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Parse `"hello" " world"`
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(
    prim_expr.to_string(color~),
    content=(
      #|string literal "hello world" (const char *)
    ),
  )
  assert_true(
    ctx.parse_prim_expr(prim_expr.tokens) is (re_prim_expr, re_rest) &&
    re_prim_expr == prim_expr &&
    re_rest is [],
  )

  // Error Check
  let rest = next_check_point(rest)
  let r = try? ctx.parse_prim_expr(rest)
  assert_true(r is Err(_))

  // let rest = next_check_point(rest)
  let r = try? ctx.parse_prim_expr(rest)
  assert_true(r is Err(_))
}
