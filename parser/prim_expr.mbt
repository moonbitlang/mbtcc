///|
///
/// PrimExpr: Primary Expression
///
/// PrimExpr represents primary expressions such as literals and identifiers.
///
/// ## Examples
///
/// ```c
/// 1           // int literal
/// 2l          // long literal
/// 3u          // unsigned int literal
/// 4ul         // unsigned long literal
/// 5ull        // unsigned long long literal
/// 6L          // long literal
/// 7U          // unsigned int literal
/// 8UL         // unsigned long literal
/// 9ll         // long long literal
/// 9.5         // double literal
/// 10.0f       // float literal
/// 'c'         // char literal
/// "hello"     // string literal
/// x           // variable identifier if the context defines `x` as a variable
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
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_prim_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (PrimExpr, ArrayView[Token]) raise ParseError
/// ```
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
pub fn PrimExpr::to_string(self : Self, color? : Bool = true) -> String {
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
  "\{prefix} \{self.kind} \{ctype}"
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
/// Parse a primary expression from the given tokens.
///
/// Returns a tuple of the parsed PrimExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// 1           // int literal
/// 2l          // long literal
/// 3u          // unsigned int literal
/// 4ul         // unsigned long literal
/// 5ull        // unsigned long long literal
/// 6L          // long literal
/// 7U          // unsigned int literal
/// 8UL         // unsigned long literal
/// 9ll         // long long literal
/// 9.5         // double literal
/// 10.0f       // float literal
/// 'c'         // char literal
/// "hello"     // string literal
/// x           // variable identifier if the context defines `x` as a variable
/// ```
///
/// ## Example Code:
///
/// ```mbt
/// let code = "42u"
/// let ctx = Context::new(code~, source_file="demo")
/// let (prim_expr, rest) = ctx.parse_prim_expr(ctx.tokens)
/// inspect(
///   prim_expr.to_string(color=false),
///   content="unsigned int literal 42u (unsigned int)"
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError in the following cases:
///
/// 1. Meet illegal tokens that cannot be parsed as primary expressions.
///
///    e.g.,
///
///    ```c
///    ? // invalid token
///    ```
///
///    The tokens that can be parsed as primary expressions are:
///
///    Token(Int), Token(Long), Token(LongLong), Token(UInt),
///    Token(ULong), Token(ULongLong), Token(Float),
///    Token(Double), Token(Char), Token(String),
///    Token(Identifier(id)) which `id` is defined as a variable name.
///
/// 2. Encounter an identifier that is not defined as a variable name in the context.
///
///    e.g.,
///    ```c
///    typedef Integer int;
///    int x = Integer; // 'Integer' is not a variable
///    ```
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
    [{ kind: Bracket('('), .. } as tok, ..] =>
      // TODO: Implement parenthesized expressions
      raise ParseError(tok, "Parenthesized expressions are not yet implemented")
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
pub fn PrimExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    Ident(_) => false
    _ => true
  }
}

///|
pub fn PrimExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    Int(v) => v
    Long(v) => v.to_int()
    LongLong(v) => v.to_int()
    UInt(v) => v.reinterpret_as_int()
    ULong(v) => v.to_int()
    ULongLong(v) => v.to_int()
    _ => {
      let msg = "Cannot evaluate PrimExpr as int: not an integer literal"
      raise ParseError(self.tokens[0], msg)
    }
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

///|
test "PrimExpr Error Test" {
  // Error test: undefined variable
  let code_err1 = "undefined_var"
  let ctx_err1 = Context::new(code=code_err1)
  let r = try? ctx_err1.parse_prim_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: typedef used as variable
  let code_err2 = "Integer"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_typedef("Integer", CType::int())
  let r = try? ctx_err2.parse_prim_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: invalid token
  let code_err3 = "?"
  let ctx_err3 = Context::new(code=code_err3)
  let r = try? ctx_err3.parse_prim_expr(ctx_err3.tokens)
  assert_true(r is Err(_))
}

///|
test "PrimExpr Constant Eval Test" {
  // Test eval_as_int for integer literals
  let code =
    #|42 ; 100l ; 200ll ; 300u ; 400ul ; 500ull ; 
    #|0 ; 1000 ; 2147483647 ;
    #|3.14 ; 2.5f ; 'c' ; "hello" ; x ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())

  // Parse and eval `42` (int literal)
  let (prim_expr, rest) = ctx.parse_prim_expr(ctx.tokens)
  inspect(prim_expr.eval_as_int(), content="42")
  assert_true(prim_expr.is_constant())

  // Parse and eval `100l` (long literal)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="100")
  assert_true(prim_expr.is_constant())

  // Parse and eval `200ll` (long long literal)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="200")
  assert_true(prim_expr.is_constant())

  // Parse and eval `300u` (unsigned int literal)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="300")
  assert_true(prim_expr.is_constant())

  // Parse and eval `400ul` (unsigned long literal)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="400")
  assert_true(prim_expr.is_constant())

  // Parse and eval `500ull` (unsigned long long literal)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="500")
  assert_true(prim_expr.is_constant())

  // Parse and eval `0` (zero)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="0")
  assert_true(prim_expr.is_constant())

  // Parse and eval `1000` (larger int)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="1000")
  assert_true(prim_expr.is_constant())

  // Parse and eval `2147483647` (max int)
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  inspect(prim_expr.eval_as_int(), content="2147483647")
  assert_true(prim_expr.is_constant())

  // Error test: double literal cannot be evaluated as int
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  assert_true(prim_expr.is_constant())
  let r = try? prim_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: float literal cannot be evaluated as int
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  assert_true(prim_expr.is_constant())
  let r = try? prim_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: char literal cannot be evaluated as int
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  assert_true(prim_expr.is_constant())
  let r = try? prim_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: string literal cannot be evaluated as int
  let rest = next_check_point(rest)
  let (prim_expr, rest) = ctx.parse_prim_expr(rest)
  assert_true(prim_expr.is_constant())
  let r = try? prim_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: variable identifier is not constant
  let rest = next_check_point(rest)
  let (prim_expr, _rest) = ctx.parse_prim_expr(rest)
  assert_false(prim_expr.is_constant())
  let r = try? prim_expr.eval_as_int()
  assert_true(r is Err(_))
}
