///|
///
/// Inclusive Or Expression (Bitwise OR)
///
/// Inclusive or expressions are binary expressions that perform
/// bitwise OR operations on exclusive or expressions.
///
/// ## Examples
///
/// ```c
/// a | b;       // Bitwise OR
/// x | 0xFF;    // Set bits
/// a | b | c;   // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// inclusive_or_expression
///   : exclusive_or_expression
///   | inclusive_or_expression '|' exclusive_or_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_inclusive_or_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (InclusiveOrExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct InclusiveOrExpr {
  kind : InclusiveOrExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for InclusiveOrExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for InclusiveOrExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// inclusive or expr: | \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn InclusiveOrExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    ExclusiveOrExpr(xor_expr) => xor_expr.to_string(color~)
    InclusiveOrExpr(left, right) => {
      let prefix = if color {
        @color.taint("inclusive or expr: | ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "inclusive or expr: | " + "(\{self.ctype})"
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
pub enum InclusiveOrExprKind {
  ExclusiveOrExpr(ExclusiveOrExpr)
  InclusiveOrExpr(InclusiveOrExpr, ExclusiveOrExpr)
} derive(Eq)

///|
/// Parse an inclusive or expression from the given tokens.
///
/// Returns a tuple containing the parsed InclusiveOrExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a | b;       // Bitwise OR
/// x | 0xFF;    // Set bits
/// a | b | c;   // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x | y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (or_expr, rest) = ctx.parse_inclusive_or_expr(ctx.tokens)
/// inspect(
///   or_expr.to_string(color=false),
///   content=(
///     #|inclusive or expr: | (int)
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
/// 1. Parse exclusive or expression fails.
///
///    e.g.,
///
///    ```c
///    | 10  // invalid exclusive or expression before '|'
///    ```
///
/// 2. The operand type is not an integer type.
///
///    e.g.,
///    ```c
///    float f;
///    int i;
///    f | i;  // Invalid use of '|' operator on float type
///    ```
pub fn Context::parse_inclusive_or_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (InclusiveOrExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_xor_expr, rest) = self.parse_exclusive_or_expr(tokens)
  let mut or_expr = InclusiveOrExpr::{
    kind: ExclusiveOrExpr(first_xor_expr),
    ctype: first_xor_expr.ctype,
    tokens: first_xor_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("|"), .. } as op_tok, .. rest] => {
      let (right_xor_expr, rest) = self.parse_exclusive_or_expr(rest)
      if !or_expr.ctype.is_integral() {
        let msg = "Invalid left operand to '|': '\{or_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      if !right_xor_expr.ctype.is_integral() {
        let msg = "Invalid right operand to '|': '\{right_xor_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      or_expr = InclusiveOrExpr::{
        kind: InclusiveOrExpr(or_expr, right_xor_expr),
        ctype: or_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (or_expr, rest)
}

///|
pub fn InclusiveOrExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    ExclusiveOrExpr(xor_expr) => xor_expr.is_constant()
    InclusiveOrExpr(left, right) => left.is_constant() && right.is_constant()
  }
}

///|
pub fn InclusiveOrExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    ExclusiveOrExpr(xor_expr) => xor_expr.eval_as_int()
    InclusiveOrExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      left_val | right_val
    }
  }
}

///|
///
/// Logical Or Expression (Logical OR)
///
/// Logical or expressions are binary expressions that perform
/// logical OR operations on logical and expressions, yielding a boolean result.
///
/// ## Examples
///
/// ```c
/// a || b;       // Logical OR
/// x > 10 || y < 5;  // Condition check
/// p || q;       // Pointer check
/// a || b || c;  // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// logical_or_expression
///   : logical_and_expression
///   | logical_or_expression '||' logical_and_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_logical_or_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (LogicalOrExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct LogicalOrExpr {
  kind : LogicalOrExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for LogicalOrExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for LogicalOrExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// logical or expr: || \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn LogicalOrExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    LogicalAndExpr(and_expr) => and_expr.to_string(color~)
    LogicalOrExpr(left, right) => {
      let prefix = if color {
        @color.taint("logical or expr: || ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "logical or expr: || " + "(\{self.ctype})"
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
pub enum LogicalOrExprKind {
  LogicalAndExpr(LogicalAndExpr)
  LogicalOrExpr(LogicalOrExpr, LogicalAndExpr)
} derive(Eq)

///|
/// Parse a logical or expression from the given tokens.
///
/// Returns a tuple containing the parsed LogicalOrExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a || b;       // Logical OR
/// x > 10 || y < 5;  // Condition check
/// p || q;       // Pointer check
/// a || b || c;  // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x || y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (logical_or_expr, rest) = ctx.parse_logical_or_expr(ctx.tokens)
/// inspect(
///   logical_or_expr.to_string(color=false),
///   content=(
///     #|logical or expr: || (int)
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
/// 1. Parse logical and expression fails.
///
///    e.g.,
///
///    ```c
///    || 10  // invalid logical and expression before '||'
///    ```
///
/// 2. The operand type is not a scalar type (void is not allowed).
///
///    Note: Like logical AND, logical OR operators accept any scalar type
///    (integers, floats, pointers) but not void or aggregate types.
///
///    e.g.,
///    ```c
///    void v;
///    int i;
///    v || i;  // Invalid: void is not a scalar type
///    ```
pub fn Context::parse_logical_or_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (LogicalOrExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_and_expr, rest) = self.parse_logical_and_expr(tokens)
  let mut logical_or_expr = LogicalOrExpr::{
    kind: LogicalAndExpr(first_and_expr),
    ctype: first_and_expr.ctype,
    tokens: first_and_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("||"), .. } as op_tok, .. rest] => {
      let (right_and_expr, rest) = self.parse_logical_and_expr(rest)
      // Check if operands are scalar types (can be converted to boolean)
      // Scalar types include: integers, floats, and pointers
      // Not allowed: void, struct, union, array
      let left_ok = logical_or_expr.ctype.is_scalar()
      let right_ok = right_and_expr.ctype.is_scalar()
      if !left_ok {
        let msg = "Invalid left operand to '||': '\{logical_or_expr.ctype}' is not a scalar type"
        raise ParseError(op_tok, msg)
      }
      if !right_ok {
        let msg = "Invalid right operand to '||': '\{right_and_expr.ctype}' is not a scalar type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result: 0 or 1)
      logical_or_expr = LogicalOrExpr::{
        kind: LogicalOrExpr(logical_or_expr, right_and_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (logical_or_expr, rest)
}

///|
pub fn LogicalOrExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    LogicalAndExpr(and_expr) => and_expr.is_constant()
    LogicalOrExpr(left, right) => left.is_constant() && right.is_constant()
  }
}

///|
pub fn LogicalOrExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    LogicalAndExpr(and_expr) => and_expr.eval_as_int()
    LogicalOrExpr(left, right) => {
      let left_val = left.eval_as_int()
      if left_val != 0 {
        return 1
      }
      let right_val = right.eval_as_int()
      if right_val != 0 {
        return 1
      }
      0
    }
  }
}

///|
test "Inclusive Or Expr Parse Test" {
  let color = false
  let code =
    #|x ; x | y ; a | b ; x | 0xFF ; x | y | z ; a | b | c ; 
    #|10 | 20 ; i | j | k ; x ^ y | z ; a | b ^ c ;
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

  // Parse `x` (no or operation)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(ctx.tokens)
  inspect(or_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `x | y`
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `a | b`
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `x | 0xFF`
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-variable x (int)
      #|└-int literal 255 (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `x | y | z` (left-associative)
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-inclusive or expr: | (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `a | b | c` (left-associative)
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-inclusive or expr: | (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `10 | 20` (with literals)
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-int literal 10 (int)
      #|└-int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `i | j | k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-inclusive or expr: | (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `x ^ y | z` (xor has higher precedence)
  let rest = next_check_point(rest)
  let (or_expr, rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-exclusive or expr: ^ (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )

  // Parse `a | b ^ c` (xor has higher precedence)
  let rest = next_check_point(rest)
  let (or_expr, _rest) = ctx.parse_inclusive_or_expr(rest)
  inspect(
    or_expr.to_string(color~),
    content=(
      #|inclusive or expr: | (int)
      #|├-variable a (int)
      #|└-exclusive or expr: ^ (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_inclusive_or_expr(or_expr.tokens) is (re_or_expr, re_rest) &&
    re_or_expr == or_expr &&
    re_rest is [],
  )
}

///|
test "Inclusive Or Expr Parse Error Test" {
  // Error test: float | int (left operand is not integer)
  let code_err1 = "f | i"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("f", CType::float())
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_inclusive_or_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: int | float (right operand is not integer)
  let code_err2 = "i | f"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  ctx_err2.add_var("f", CType::float())
  let r = try? ctx_err2.parse_inclusive_or_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: double | int (left operand is not integer)
  let code_err3 = "d | i"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("d", CType::double())
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_inclusive_or_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int | double (right operand is not integer)
  let code_err4 = "i | d"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("i", CType::int())
  ctx_err4.add_var("d", CType::double())
  let r = try? ctx_err4.parse_inclusive_or_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: pointer | int (pointer is not integer)
  let code_err5 = "p | i"
  let ctx_err5 = Context::new(code=code_err5)
  let int_ptr = CType::int().ptr_to()
  ctx_err5.add_var("p", int_ptr)
  ctx_err5.add_var("i", CType::int())
  let r = try? ctx_err5.parse_inclusive_or_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: struct | int (struct is not integer)
  let code_err6 = "s | i"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("s", point_struct)
  ctx_err6.add_var("i", CType::int())
  let r = try? ctx_err6.parse_inclusive_or_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}

///|
test "InclusiveOrExpr Constant Eval Test" {

}

///|
test "Logical Or Expr Parse Test" {
  let color = false
  let code =
    #|x ; x || y ; a || b ; x > 10 || y < 5 ; x || y || z ; a || b || c ; 
    #|1 || 2 ; i || j || k ; x && y || z ; a || b && c ;
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

  // Parse `x` (no logical or operation)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(ctx.tokens)
  inspect(logical_or_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `x || y`
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `a || b`
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `x > 10 || y < 5` (condition check)
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-relational expr: > (int)
      #|│ ├-variable x (int)
      #|│ └-int literal 10 (int)
      #|└-relational expr: < (int)
      #|  ├-variable y (int)
      #|  └-int literal 5 (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `x || y || z` (left-associative)
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-logical or expr: || (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `a || b || c` (left-associative)
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-logical or expr: || (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `1 || 2` (with literals)
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-int literal 1 (int)
      #|└-int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `i || j || k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-logical or expr: || (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `x && y || z` (logical and has higher precedence)
  let rest = next_check_point(rest)
  let (logical_or_expr, rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-logical and expr: && (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )

  // Parse `a || b && c` (logical and has higher precedence)
  let rest = next_check_point(rest)
  let (logical_or_expr, _rest) = ctx.parse_logical_or_expr(rest)
  inspect(
    logical_or_expr.to_string(color~),
    content=(
      #|logical or expr: || (int)
      #|├-variable a (int)
      #|└-logical and expr: && (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_logical_or_expr(logical_or_expr.tokens)
    is (re_logical_or_expr, re_rest) &&
    re_logical_or_expr == logical_or_expr &&
    re_rest is [],
  )
}

///|
test "Logical Or Expr Parse Error Test" {
  // Error test: void || int (left operand is void, not scalar)
  let code_err1 = "v || i"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("v", CType::void_())
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_logical_or_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: int || void (right operand is void, not scalar)
  let code_err2 = "i || v"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  ctx_err2.add_var("v", CType::void_())
  let r = try? ctx_err2.parse_logical_or_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: struct || int (struct is not scalar)
  let code_err3 = "s || i"
  let ctx_err3 = Context::new(code=code_err3)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err3.add_var("s", point_struct)
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_logical_or_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int || struct (right operand is struct, not scalar)
  let code_err4 = "i || s"
  let ctx_err4 = Context::new(code=code_err4)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err4.add_var("i", CType::int())
  ctx_err4.add_var("s", point_struct)
  let r = try? ctx_err4.parse_logical_or_expr(ctx_err4.tokens)
  assert_true(r is Err(_))
}

///|
test "Logical Or Expr Constant Eval Test" {

}
