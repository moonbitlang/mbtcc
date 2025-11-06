///|
///
/// Cast Expression
///
/// Cast expressions are expressions that explicitly convert a value from
/// one type to another by specifying a target type in parentheses before
/// the expression, or just wrap a unary expression without casting.
///
/// ## Examples
///
/// ```c
/// (int)3.14;            // Cast double to int
/// (float)x;             // Cast variable x to float
/// (long)(x + y);        // Cast result of expression to long
/// (char *)ptr;          // Cast pointer type
/// (unsigned int)-1;     // Cast signed to unsigned
/// x;                    // Unary expression without cast
/// ```
///
/// ## Grammar (EBNF)
///
/// cast_expression
///   : unary_expression
///   | '(' type_name ')' cast_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_cast_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (CastExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct CastExpr {
  kind : CastExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for CastExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for CastExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
/// if cast_to == unary_expr.ctype, just print unary_expr
/// if not, print like:
///
/// cast expr: cast to \{cast_to}
/// `\{unary_expr}
pub fn CastExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    UnaryExpr(unary_expr) => unary_expr.to_string(color~)
    CastTo(ctype, cast_expr) => {
      let prefix = if color {
        @color.taint("cast expr: cast to \{ctype}", Magenta)
      } else {
        "cast expr: cast to \{ctype}"
      }
      let s = cast_expr.to_string(color~)
      "\{prefix}\n" + "└-\{s}"
    }
  }
}

///|
/// Parse a cast expression from the given tokens.
///
/// Returns a tuple containing the parsed CastExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// (int)3.14;            // Cast double to int
/// (float)x;             // Cast variable x to float
/// (long)(x + y);        // Cast result of expression to long
/// (char *)ptr;          // Cast pointer type
/// (unsigned int)-1;     // Cast signed to unsigned
/// x;                    // Unary expression without cast
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// let (cast_expr, rest) = ctx.parse_cast_expr(ctx.tokens)
/// inspect(
///   cast_expr.to_string(color=false),
///   content="variable x (int)"
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse unary expression fails.
///
///    e.g.,
///    
///    ```c
///    (int)?  // invalid unary expression after cast
///    ```
///
/// 2. Type name parsing is not yet fully implemented (TODO).
///
///    When encountering `'(' type_name ')' cast_expression`, the parser
///    currently skips the type cast parsing and falls back to parsing
///    as a unary expression.
pub fn Context::parse_cast_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (CastExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  match tokens {
    [{ kind: Bracket('('), .. }, tok, ..] if self.is_keyword_or_type_name(tok) => {
      let (ctype, rest) = self.parse_type_name(tokens[1:])
      guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
        let msg = "Expected ')' after type name in cast expression"
        raise ParseError(rest[0], msg)
      }
      let (cast_expr, rest) = self.parse_cast_expr(rest)
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let cast_expr = CastExpr::{
        kind: CastTo(ctype, cast_expr),
        ctype,
        tokens,
      }
      return (cast_expr, rest)
    }
    _ => ()
  }
  let (unary_expr, rest) = self.parse_unary_expr(tokens)
  let tokens = init_toks[0:rest.start_offset() - start_offset]
  let cast_expr = CastExpr::{
    kind: UnaryExpr(unary_expr),
    ctype: unary_expr.ctype,
    tokens,
  }
  (cast_expr, rest)
}

///|
pub enum CastExprKind {
  UnaryExpr(UnaryExpr)
  CastTo(CType, CastExpr)
} derive(Eq)

///|
pub fn CastExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    UnaryExpr(unary_expr) => unary_expr.is_constant()
    CastTo(_, cast_expr) => cast_expr.is_constant()
  }
}

///|
pub fn CastExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    UnaryExpr(unary_expr) => unary_expr.eval_as_int()
    CastTo(target_type, inner_expr) => {
      // Check if target type is an integer type
      if !(target_type.dataKind
        is (Char
        | UChar
        | Int16
        | UInt16
        | Int
        | UInt
        | Long
        | ULong
        | LongLong
        | ULongLong)) {
        let msg = "Cannot evaluate CastExpr as int: target type '\{target_type}' is not an integer type"
        raise ParseError(self.tokens[0], msg)
      }
      // Check the inner expression's type
      if inner_expr.ctype.dataKind is Float ||
        inner_expr.ctype.dataKind is Double {
        // If inner expression is float or double, evaluate as double then convert to int
        inner_expr.eval_as_double().to_int()
      } else {
        // Otherwise, evaluate as int directly
        inner_expr.eval_as_int()
      }
    }
  }
}

///|
pub fn CastExpr::eval_as_double(self : Self) -> Double raise ParseError {
  match self.kind {
    UnaryExpr(unary_expr) => unary_expr.eval_as_double()
    CastTo(target_type, inner_expr) => {
      // Check if target type is a floating-point type
      if !(target_type.dataKind is Float || target_type.dataKind is Double) {
        let msg = "Cannot evaluate CastExpr as double: target type '\{target_type}' is not a floating-point type"
        raise ParseError(self.tokens[0], msg)
      }
      // Evaluate inner expression as double
      inner_expr.eval_as_double()
    }
  }
}

///|
test "CastExpr Explicit Cast Parse Test" {
  let color = false
  let code =
    #|(int)3.14 ; (long)x ; (unsigned int)-1 ; (char)65 ;
    #|(int *)ptr ; (const int *)p ; (unsigned long)100 ; (long)(long)x ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  ctx
  ..add_var("x", CType::int())
  ..add_var("ptr", CType::void_().ptr_to())
  ..add_var("p", CType::int().ptr_to())

  // Parse `(int)3.14`
  let (cast_expr, rest) = ctx.parse_cast_expr(ctx.tokens)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to int
      #|└-double literal 3.14 (double)
    ),
  )
  assert_true(cast_expr.ctype == CType::int())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(long)x`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to long
      #|└-variable x (int)
    ),
  )
  assert_true(cast_expr.ctype == CType::long())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(unsigned int)-1`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to unsigned int
      #|└-unary operator - (int)
      #|└-int literal 1 (int)
    ),
  )
  assert_true(cast_expr.ctype == CType::uint())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(char)65`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to char
      #|└-int literal 65 (int)
    ),
  )
  assert_true(cast_expr.ctype == CType::char())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(int *)ptr`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to int *
      #|└-variable ptr (void *)
    ),
  )
  assert_true(cast_expr.ctype == CType::int().ptr_to())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(const int *)p`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to const int *
      #|└-variable p (int *)
    ),
  )
  assert_true(cast_expr.ctype.is_const == false)
  assert_true(cast_expr.ctype.dataKind is Ptr({ is_const: true, .. }))
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(unsigned long)100`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to unsigned long
      #|└-int literal 100 (int)
    ),
  )
  assert_true(cast_expr.ctype == CType::ulong())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(long)(long)x` - nested cast
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to long
      #|└-cast expr: cast to long
      #|└-variable x (int)
    ),
  )
  assert_true(cast_expr.ctype == CType::long())
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // rest must be `[EOF]`
  let rest = next_check_point(rest)
  assert_true(rest is [{ kind: EOF, .. }])
}

///|
test "CastExpr Parse Test" {
  let color = false
  let code =
    #|x ; ++y ; *ptr ; -z ; 42 ; 10.0f ; "hello" ; i++ ; --j ;
    #|(x) ; (42) ; (1 + 2) ; (int)(x) ; (long)(10) ;
    #|&var ; ~flag ; !cond ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  let ctype_int = CType::int()
  let ctype_double = CType::double()
  ctx
  ..add_var("x", ctype_int)
  ..add_var("y", ctype_int)
  ..add_var("ptr", ctype_int.ptr_to())
  ..add_var("z", ctype_double)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("var", ctype_int)
  ..add_var("flag", ctype_int)
  ..add_var("cond", ctype_int)

  // Parse `x`
  let (cast_expr, rest) = ctx.parse_cast_expr(ctx.tokens)
  inspect(cast_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `++y`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ++ (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `*ptr`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator * (int)
      #|└-variable ptr (int *)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `-z`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator - (double)
      #|└-variable z (double)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `42`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.to_string(color~), content="int literal 42 (int)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `10.0f`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.to_string(color~), content="float literal 10f (float)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `"hello"`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|string literal "hello" (const char *)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `i++`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ++ (int)
      #|└-variable i (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `--j`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator -- (int)
      #|└-variable j (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(x)` - parenthesized variable
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(42)` - parenthesized literal
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.to_string(color~), content="int literal 42 (int)")
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(1 + 2)` - parenthesized expression
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-int literal 1 (int)
      #|└-int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(int)(x)` - cast with parenthesized variable
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to int
      #|└-variable x (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `(long)(10)` - cast with parenthesized literal
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|cast expr: cast to long
      #|└-int literal 10 (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `&var`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator & (int *)
      #|└-variable var (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `~flag`
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ~ (int)
      #|└-variable flag (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )

  // Parse `!cond`
  let rest = next_check_point(rest)
  let (cast_expr, _rest) = ctx.parse_cast_expr(rest)
  inspect(
    cast_expr.to_string(color~),
    content=(
      #|unary operator ! (int)
      #|└-variable cond (int)
    ),
  )
  assert_true(
    ctx.parse_cast_expr(cast_expr.tokens) is (re_cast_expr, re_rest) &&
    re_cast_expr == cast_expr &&
    re_rest is [],
  )
}

///|
test "CastExpr Constant Eval Test" {
  // Test eval_as_int for cast expressions
  let code =
    #|42 ; -10 ; ~5 ; !0 ; !1 ;
    #|100l ; 200u ;
    #|(int)42 ; (long)100 ; (unsigned int)200 ; (char)65 ;
    #|(int)3.14 ; (long)!0 ; (unsigned long)~5 ;
    #|10.0f ; 3.14 ; (float)42 ; (double)100 ;
    #|x ; ++y ; --z ; (int)x ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())
  ctx.add_var("z", CType::int())

  // Parse and eval `42` (int literal wrapped in CastExpr)
  let (cast_expr, rest) = ctx.parse_cast_expr(ctx.tokens)
  inspect(cast_expr.eval_as_int(), content="42")
  assert_true(cast_expr.is_constant())

  // Parse and eval `-10` (negation wrapped in CastExpr)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="-10")
  assert_true(cast_expr.is_constant())

  // Parse and eval `~5` (bitwise NOT wrapped in CastExpr)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="-6")
  assert_true(cast_expr.is_constant())

  // Parse and eval `!0` (logical NOT wrapped in CastExpr)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="1")
  assert_true(cast_expr.is_constant())

  // Parse and eval `!1` (logical NOT wrapped in CastExpr)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="0")
  assert_true(cast_expr.is_constant())

  // Parse and eval `100l` (long literal wrapped in CastExpr)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="100")
  assert_true(cast_expr.is_constant())

  // Parse and eval `200u` (unsigned int literal wrapped in CastExpr)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="200")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(int)42` (explicit cast to int)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="42")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(long)100` (explicit cast to long)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="100")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(unsigned int)200` (explicit cast to unsigned int)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="200")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(char)65` (explicit cast to char)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="65")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(int)3.14` (explicit cast from double to int)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="3")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(long)!0` (explicit cast of logical NOT result)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="1")
  assert_true(cast_expr.is_constant())

  // Parse and eval `(unsigned long)~5` (explicit cast of bitwise NOT)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  inspect(cast_expr.eval_as_int(), content="-6")
  assert_true(cast_expr.is_constant())

  // Error test: float literal (cast_to is float, not integer)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_true(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: double literal (cast_to is double, not integer)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_true(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: (float)42 - explicit cast to float (not integer type)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_true(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: (double)100 - explicit cast to double (not integer type)
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_true(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: variable is not constant
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_false(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: pre-increment is not constant
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_false(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: pre-decrement is not constant
  let rest = next_check_point(rest)
  let (cast_expr, rest) = ctx.parse_cast_expr(rest)
  assert_false(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: (int)x - cast of variable is not constant
  let rest = next_check_point(rest)
  let (cast_expr, _rest) = ctx.parse_cast_expr(rest)
  assert_false(cast_expr.is_constant())
  let r = try? cast_expr.eval_as_int()
  assert_true(r is Err(_))
}
