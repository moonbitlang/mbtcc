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
  unary_expr : UnaryExpr
  // if no `(typename)` cast
  // set `cst_to` is same as `unary_expr.ctype`
  cast_to : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for CastExpr with equal(self, other) {
  self.unary_expr == other.unary_expr && self.cast_to == other.cast_to
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
  if self.cast_to == self.unary_expr.ctype {
    return self.unary_expr.to_string(color~)
  }
  let prefix = if color {
    @color.taint("cast expr: cast to \{self.cast_to}", Magenta)
  } else {
    "cast expr: cast to \{self.cast_to}"
  }
  let s = self.unary_expr.to_string(color~)
  "\{prefix}\n" + "└-\{s}"
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
    [{ kind: Bracket('('), .. }, tok, ..] if self.is_keyword_or_type_name(tok) =>
      //TODO: Skip for we didn't implement type_name parser yet
      // Call parse_cast_expr recursively, so it will return
      ...
    _ => ()
  }
  let (unary_expr, rest) = self.parse_unary_expr(tokens)
  let tokens = init_toks[0:rest.start_offset() - start_offset]
  let cast_to = unary_expr.ctype
  let cast_expr = CastExpr::{ unary_expr, cast_to, tokens }
  (cast_expr, rest)
}

///|
pub fn CastExpr::is_constant(self : Self) -> Bool {
  self.unary_expr.is_constant()
}

///|
pub fn CastExpr::eval_as_int(self : Self) -> Int raise ParseError {
  if !(self.cast_to.dataKind
    is (Int | UInt | Long | ULong | LongLong | ULongLong)) {
    let msg = "Cannot evaluate CastExpr as int: cast_to type is not integer"
    raise ParseError(self.tokens[0], msg)
  }
  self.unary_expr.eval_as_int()
}

///|
///
/// TODO: need another test way.
///
/// Test parsing cast expressions (currently only unary expressions are tested
/// since type_name casting is not yet fully implemented)
test "CastExpr Parse Test" {
  let color = false
  let code =
    #|x ; ++y ; *ptr ; -z ; 42 ; 10.0f ; "hello" ; i++ ; --j ;
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
