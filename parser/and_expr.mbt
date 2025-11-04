///|
///
/// And Expression (Bitwise AND)
///
/// And expressions are binary expressions that perform
/// bitwise AND operations on equality expressions.
///
/// ## Examples
///
/// ```c
/// a & b;       // Bitwise AND
/// x & 0xFF;    // Mask operation
/// a & b & c;   // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// and_expression
///   : equality_expression
///   | and_expression '&' equality_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_and_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (AndExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct AndExpr {
  kind : AndExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AndExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for AndExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// and expr: & \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn AndExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    EqualityExpr(equality_expr) => equality_expr.to_string(color~)
    AndExpr(left, right) => {
      let prefix = if color {
        @color.taint("and expr: & ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "and expr: & " + "(\{self.ctype})"
      }
      let left_str = left.to_string(color~)
      let right_str = right.to_string(color~)
      // Add backtick prefix to each line of nested expressions
      let left_lines = left_str.split("\n")
      let left_formatted = format_lines(
        left_lines,
        head_with="├-",
        continue_with="│ ",
      )
      let right_lines = right_str.split("\n")
      let right_formatted = format_lines(
        right_lines,
        head_with="└-",
        continue_with="  ",
      )
      "\{prefix}\n\{left_formatted}\n\{right_formatted}"
    }
  }
}

///|
pub enum AndExprKind {
  EqualityExpr(EqualityExpr)
  AndExpr(AndExpr, EqualityExpr)
} derive(Eq)

///|
/// Parse an and expression from the given tokens.
///
/// Returns a tuple containing the parsed AndExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a & b;       // Bitwise AND
/// x & 0xFF;    // Mask operation
/// a & b & c;   // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x & y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (and_expr, rest) = ctx.parse_and_expr(ctx.tokens)
/// inspect(
///   and_expr.to_string(color=false),
///   content=(
///     #|and expr: & (int)
///     #|├-variable x (int)
///     #|└-variable y (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse equality expression fails.
///
///    e.g.,
///
///    ```c
///    & 10  // invalid equality expression before '&'
///    ```
///
/// 2. The operand type is not an integer type.
///
///    e.g.,
///    ```c
///    float f;
///    int i;
///    f & i;  // Invalid use of '&' operator on float type
///    ```
pub fn Context::parse_and_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AndExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_equality_expr, rest) = self.parse_equality_expr(tokens)
  let mut and_expr = AndExpr::{
    kind: EqualityExpr(first_equality_expr),
    ctype: first_equality_expr.ctype,
    tokens: first_equality_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("&"), .. } as op_tok, .. rest] => {
      let (right_equality_expr, rest) = self.parse_equality_expr(rest)
      if !and_expr.ctype.is_integral() {
        let msg = "Invalid left operand to '&': '\{and_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      if !right_equality_expr.ctype.is_integral() {
        let msg = "Invalid right operand to '&': '\{right_equality_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      and_expr = AndExpr::{
        kind: AndExpr(and_expr, right_equality_expr),
        ctype: and_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (and_expr, rest)
}

///|
///
/// Logical And Expression (Logical AND)
///
/// Logical and expressions are binary expressions that perform
/// logical AND operations on inclusive or expressions, yielding a boolean result.
///
/// ## Examples
///
/// ```c
/// a && b;       // Logical AND
/// x > 0 && x < 10;  // Range check
/// p && *p;      // Pointer check and dereference
/// a && b && c;  // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// logical_and_expression
///   : inclusive_or_expression
///   | logical_and_expression '&&' inclusive_or_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_logical_and_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (LogicalAndExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct LogicalAndExpr {
  kind : LogicalAndExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for LogicalAndExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for LogicalAndExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// logical and expr: && \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn LogicalAndExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    InclusiveOrExpr(or_expr) => or_expr.to_string(color~)
    LogicalAndExpr(left, right) => {
      let prefix = if color {
        @color.taint("logical and expr: && ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "logical and expr: && " + "(\{self.ctype})"
      }
      let left_str = left.to_string(color~)
      let right_str = right.to_string(color~)
      // Add backtick prefix to each line of nested expressions
      let left_lines = left_str.split("\n")
      let left_formatted = format_lines(
        left_lines,
        head_with="├-",
        continue_with="│ ",
      )
      let right_lines = right_str.split("\n")
      let right_formatted = format_lines(
        right_lines,
        head_with="└-",
        continue_with="  ",
      )
      "\{prefix}\n\{left_formatted}\n\{right_formatted}"
    }
  }
}

///|
pub enum LogicalAndExprKind {
  InclusiveOrExpr(InclusiveOrExpr)
  LogicalAndExpr(LogicalAndExpr, InclusiveOrExpr)
} derive(Eq)

///|
/// Parse a logical and expression from the given tokens.
///
/// Returns a tuple containing the parsed LogicalAndExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a && b;       // Logical AND
/// x > 0 && x < 10;  // Range check
/// p && *p;      // Pointer check and dereference
/// a && b && c;  // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x && y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (logical_and_expr, rest) = ctx.parse_logical_and_expr(ctx.tokens)
/// inspect(
///   logical_and_expr.to_string(color=false),
///   content=(
///     #|logical and expr: && (int)
///     #|├-variable x (int)
///     #|└-variable y (int)
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse inclusive or expression fails.
///
///    e.g.,
///
///    ```c
///    && 10  // invalid inclusive or expression before '&&'
///    ```
///
/// 2. The operand type is not a scalar type (void is not allowed).
///
///    Note: Unlike bitwise operators, logical operators accept any scalar type
///    (integers, floats, pointers) but not void or aggregate types.
///
///    e.g.,
///    ```c
///    void v;
///    int i;
///    v && i;  // Invalid: void is not a scalar type
///    ```
pub fn Context::parse_logical_and_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (LogicalAndExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_or_expr, rest) = self.parse_inclusive_or_expr(tokens)
  let mut logical_and_expr = LogicalAndExpr::{
    kind: InclusiveOrExpr(first_or_expr),
    ctype: first_or_expr.ctype,
    tokens: first_or_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("&&"), .. } as op_tok, .. rest] => {
      let (right_or_expr, rest) = self.parse_inclusive_or_expr(rest)
      // Check if operands are scalar types (can be converted to boolean)
      // Scalar types include: integers, floats, and pointers
      // Not allowed: void, struct, union, array
      let left_ok = logical_and_expr.ctype.is_scalar()
      let right_ok = right_or_expr.ctype.is_scalar()
      if !left_ok {
        let msg = "Invalid left operand to '&&': '\{logical_and_expr.ctype}' is not a scalar type"
        raise ParseError(op_tok, msg)
      }
      if !right_ok {
        let msg = "Invalid right operand to '&&': '\{right_or_expr.ctype}' is not a scalar type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result: 0 or 1)
      logical_and_expr = LogicalAndExpr::{
        kind: LogicalAndExpr(logical_and_expr, right_or_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (logical_and_expr, rest)
}

///|
test "And Expr Parse Test" {
  let color = false
  let code =
    #|x ; x & y ; a & b ; x & 0xFF ; x & y & z ; a & b & c ; 
    #|10 & 20 ; i & j & k ; x == y & z ; a & b == c ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  let ctype_int = CType::int()
  ctx
  ..add_var("x", ctype_int)
  ..add_var("y", ctype_int)
  ..add_var("a", ctype_int)
  ..add_var("b", ctype_int)
  ..add_var("z", ctype_int)
  ..add_var("c", ctype_int)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("k", ctype_int)

  // Parse `x` (no and operation)
  let (and_expr, rest) = ctx.parse_and_expr(ctx.tokens)
  inspect(and_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `x & y`
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `a & b`
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `x & 0xFF`
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-variable x (int)
      #|└-int literal 255 (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `x & y & z` (left-associative)
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-and expr: & (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `a & b & c` (left-associative)
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-and expr: & (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `10 & 20` (with literals)
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-int literal 10 (int)
      #|└-int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `i & j & k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-and expr: & (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `x == y & z` (equality has higher precedence)
  let rest = next_check_point(rest)
  let (and_expr, rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-equality expr: == (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )

  // Parse `a & b == c` (equality has higher precedence)
  let rest = next_check_point(rest)
  let (and_expr, _rest) = ctx.parse_and_expr(rest)
  inspect(
    and_expr.to_string(color~),
    content=(
      #|and expr: & (int)
      #|├-variable a (int)
      #|└-equality expr: == (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_and_expr(and_expr.tokens) is (re_and_expr, re_rest) &&
    re_and_expr == and_expr &&
    re_rest is [],
  )
}

///|
test "And Expr Parse Error Test" {
  // Error test: float & int (left operand is not integer)
  let code_err1 = "f & i"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("f", CType::float())
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_and_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: int & float (right operand is not integer)
  let code_err2 = "i & f"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  ctx_err2.add_var("f", CType::float())
  let r = try? ctx_err2.parse_and_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: double & int (left operand is not integer)
  let code_err3 = "d & i"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("d", CType::double())
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_and_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int & double (right operand is not integer)
  let code_err4 = "i & d"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("i", CType::int())
  ctx_err4.add_var("d", CType::double())
  let r = try? ctx_err4.parse_and_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: pointer & int (pointer is not integer)
  let code_err5 = "p & i"
  let ctx_err5 = Context::new(code=code_err5)
  let int_ptr = CType::int().ptr_to()
  ctx_err5.add_var("p", int_ptr)
  ctx_err5.add_var("i", CType::int())
  let r = try? ctx_err5.parse_and_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: struct & int (struct is not integer)
  let code_err6 = "s & i"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("s", point_struct)
  ctx_err6.add_var("i", CType::int())
  let r = try? ctx_err6.parse_and_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}

///|
test "Logical And Expr Parse Test" {
  let color = false
  let code =
    #|x ; x && y ; a && b ; x > 0 && x < 10 ; x && y && z ; a && b && c ; 
    #|1 && 2 ; i && j && k ; x | y && z ; a && b | c ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  let ctype_int = CType::int()
  let ctype_ptr = CType::int().ptr_to()
  ctx
  ..add_var("x", ctype_int)
  ..add_var("y", ctype_int)
  ..add_var("a", ctype_int)
  ..add_var("b", ctype_int)
  ..add_var("z", ctype_int)
  ..add_var("c", ctype_int)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("k", ctype_int)

  // Parse `x` (no logical and operation)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(ctx.tokens)
  inspect(logical_and_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `x && y`
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `a && b`
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `x > 0 && x < 10` (range check)
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-relational expr: > (int)
      #|│ ├-variable x (int)
      #|│ └-int literal 0 (int)
      #|└-relational expr: < (int)
      #|  ├-variable x (int)
      #|  └-int literal 10 (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `x && y && z` (left-associative)
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-logical and expr: && (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `a && b && c` (left-associative)
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-logical and expr: && (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `1 && 2` (with literals)
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-int literal 1 (int)
      #|└-int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `i && j && k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-logical and expr: && (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `x | y && z` (inclusive or has higher precedence)
  let rest = next_check_point(rest)
  let (logical_and_expr, rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-inclusive or expr: | (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )

  // Parse `a && b | c` (inclusive or has higher precedence)
  let rest = next_check_point(rest)
  let (logical_and_expr, _rest) = ctx.parse_logical_and_expr(rest)
  inspect(
    logical_and_expr.to_string(color~),
    content=(
      #|logical and expr: && (int)
      #|├-variable a (int)
      #|└-inclusive or expr: | (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_logical_and_expr(logical_and_expr.tokens)
    is (re_logical_and_expr, re_rest) &&
    re_logical_and_expr == logical_and_expr &&
    re_rest is [],
  )
}

///|
test "Logical And Expr Parse Error Test" {
  // Error test: void && int (left operand is void, not scalar)
  let code_err1 = "v && i"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("v", CType::void_())
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_logical_and_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: int && void (right operand is void, not scalar)
  let code_err2 = "i && v"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  ctx_err2.add_var("v", CType::void_())
  let r = try? ctx_err2.parse_logical_and_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: struct && int (struct is not scalar)
  let code_err3 = "s && i"
  let ctx_err3 = Context::new(code=code_err3)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err3.add_var("s", point_struct)
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_logical_and_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int && struct (right operand is struct, not scalar)
  let code_err4 = "i && s"
  let ctx_err4 = Context::new(code=code_err4)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err4.add_var("i", CType::int())
  ctx_err4.add_var("s", point_struct)
  let r = try? ctx_err4.parse_logical_and_expr(ctx_err4.tokens)
  assert_true(r is Err(_))
}
