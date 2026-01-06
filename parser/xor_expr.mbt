///|
///
/// Exclusive Or Expression (Bitwise XOR)
///
/// Exclusive or expressions are binary expressions that perform
/// bitwise XOR operations on and expressions.
///
/// ## Examples
///
/// ```c
/// a ^ b;       // Bitwise XOR
/// x ^ 0xFF;    // Toggle bits
/// a ^ b ^ c;   // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// exclusive_or_expression
///   : and_expression
///   | exclusive_or_expression '^' and_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_exclusive_or_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (ExclusiveOrExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct ExclusiveOrExpr {
  kind : ExclusiveOrExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ExclusiveOrExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for ExclusiveOrExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// exclusive or expr: ^ \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn ExclusiveOrExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    AndExpr(and_expr) => and_expr.to_string(color~)
    ExclusiveOrExpr(left, right) => {
      let prefix = if color {
        @color.taint("exclusive or expr: ^ ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "exclusive or expr: ^ " + "(\{self.ctype})"
      }
      let left_str = left.to_string(color~)
      let right_str = right.to_string(color~)
      // Add backtick prefix to each line of nested expressions
      let left_lines = left_str.split("\n").to_array().iterator()
      let left_formatted = format_lines(
        left_lines,
        head_with="├-",
        continue_with="│ ",
      )
      let right_lines = right_str.split("\n").to_array().iterator()
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
pub enum ExclusiveOrExprKind {
  AndExpr(AndExpr)
  ExclusiveOrExpr(ExclusiveOrExpr, AndExpr)
} derive(Eq)

///|
/// Parse an exclusive or expression from the given tokens.
///
/// Returns a tuple containing the parsed ExclusiveOrExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a ^ b;       // Bitwise XOR
/// x ^ 0xFF;    // Toggle bits
/// a ^ b ^ c;   // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x ^ y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (xor_expr, rest) = ctx.parse_exclusive_or_expr(ctx.tokens)
/// inspect(
///   xor_expr.to_string(color=false),
///   content=(
///     #|exclusive or expr: ^ (int)
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
/// 1. Parse and expression fails.
///
///    e.g.,
///
///    ```c
///    ^ 10  // invalid and expression before '^'
///    ```
///
/// 2. The operand type is not an integer type.
///
///    e.g.,
///    ```c
///    float f;
///    int i;
///    f ^ i;  // Invalid use of '^' operator on float type
///    ```
pub fn Context::parse_exclusive_or_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ExclusiveOrExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_and_expr, rest) = self.parse_and_expr(tokens)
  let mut xor_expr = ExclusiveOrExpr::{
    kind: AndExpr(first_and_expr),
    ctype: first_and_expr.ctype,
    tokens: first_and_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("^"), .. } as op_tok, .. rest] => {
      let (right_and_expr, rest) = self.parse_and_expr(rest)
      if !xor_expr.ctype.is_integral() {
        let msg = "Invalid left operand to '^': '\{xor_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      if !right_and_expr.ctype.is_integral() {
        let msg = "Invalid right operand to '^': '\{right_and_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      xor_expr = ExclusiveOrExpr::{
        kind: ExclusiveOrExpr(xor_expr, right_and_expr),
        ctype: xor_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (xor_expr, rest)
}

///|
pub fn ExclusiveOrExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    AndExpr(and_expr) => and_expr.is_constant()
    ExclusiveOrExpr(left, right) => left.is_constant() && right.is_constant()
  }
}

///|
pub fn ExclusiveOrExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    AndExpr(and_expr) => and_expr.eval_as_int()
    ExclusiveOrExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      left_val ^ right_val
    }
  }
}

///|
test "Exclusive Or Expr Parse Test" {
  let color = false
  let code =
    #|x ; x ^ y ; a ^ b ; x ^ 0xFF ; x ^ y ^ z ; a ^ b ^ c ; 
    #|10 ^ 20 ; i ^ j ^ k ; x & y ^ z ; a ^ b & c ;
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

  // Parse `x` (no xor operation)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(ctx.tokens)
  inspect(xor_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `x ^ y`
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `a ^ b`
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `x ^ 0xFF`
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-variable x (int)
      #|└-int literal 255 (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `x ^ y ^ z` (left-associative)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-exclusive or expr: ^ (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `a ^ b ^ c` (left-associative)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-exclusive or expr: ^ (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `10 ^ 20` (with literals)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-int literal 10 (int)
      #|└-int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `i ^ j ^ k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-exclusive or expr: ^ (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `x & y ^ z` (and has higher precedence)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-and expr: & (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )

  // Parse `a ^ b & c` (and has higher precedence)
  let rest = next_check_point(rest)
  let (xor_expr, _rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(
    xor_expr.to_string(color~),
    content=(
      #|exclusive or expr: ^ (int)
      #|├-variable a (int)
      #|└-and expr: & (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_exclusive_or_expr(xor_expr.tokens) is (re_xor_expr, re_rest) &&
    re_xor_expr == xor_expr &&
    re_rest is [],
  )
}

///|
test "Exclusive Or Expr Parse Error Test" {
  // Error test: float ^ int (left operand is not integer)
  let code_err1 = "f ^ i"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("f", CType::float())
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_exclusive_or_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: int ^ float (right operand is not integer)
  let code_err2 = "i ^ f"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  ctx_err2.add_var("f", CType::float())
  let r = try? ctx_err2.parse_exclusive_or_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: double ^ int (left operand is not integer)
  let code_err3 = "d ^ i"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("d", CType::double())
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_exclusive_or_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int ^ double (right operand is not integer)
  let code_err4 = "i ^ d"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("i", CType::int())
  ctx_err4.add_var("d", CType::double())
  let r = try? ctx_err4.parse_exclusive_or_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: pointer ^ int (pointer is not integer)
  let code_err5 = "p ^ i"
  let ctx_err5 = Context::new(code=code_err5)
  let int_ptr = CType::int().ptr_to()
  ctx_err5.add_var("p", int_ptr)
  ctx_err5.add_var("i", CType::int())
  let r = try? ctx_err5.parse_exclusive_or_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: struct ^ int (struct is not integer)
  let code_err6 = "s ^ i"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("s", point_struct)
  ctx_err6.add_var("i", CType::int())
  let r = try? ctx_err6.parse_exclusive_or_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}

///|
test "ExclusiveOrExpr Constant Eval Test" {
  // Test eval_as_int for bitwise xor expressions
  let code =
    #|42 ; 15 ^ 7 ; 255 ^ 15 ; 12 ^ 10 ;
    #|7 ^ 3 ^ 1 ; 255 ^ 240 ^ 15 ;
    #|5 == 5 ^ 1 ; 10 != 5 ^ 1 ; 15 & 7 ^ 3 ;
    #|x ^ 7 ; 15 ^ y ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())

  // Parse and eval `42` (just an and expr wrapped in ExclusiveOrExpr)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(ctx.tokens)
  inspect(xor_expr.eval_as_int(), content="42")
  assert_true(xor_expr.is_constant())

  // Parse and eval `15 ^ 7` (bitwise XOR: 15 ^ 7 = 8)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="8")
  assert_true(xor_expr.is_constant())

  // Parse and eval `255 ^ 15` (bitwise XOR: 255 ^ 15 = 240)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="240")
  assert_true(xor_expr.is_constant())

  // Parse and eval `12 ^ 10` (bitwise XOR: 12 ^ 10 = 6)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="6")
  assert_true(xor_expr.is_constant())

  // Parse and eval `7 ^ 3 ^ 1` (left-associative: (7^3)^1 = 4^1 = 5)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="5")
  assert_true(xor_expr.is_constant())

  // Parse and eval `255 ^ 240 ^ 15` (left-associative: (255^240)^15 = 15^15 = 0)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="0")
  assert_true(xor_expr.is_constant())

  // Parse and eval `5 == 5 ^ 1` (equality has higher precedence: (5==5)^1 = 1^1 = 0)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="0")
  assert_true(xor_expr.is_constant())

  // Parse and eval `10 != 5 ^ 1` (equality has higher precedence: (10!=5)^1 = 1^1 = 0)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="0")
  assert_true(xor_expr.is_constant())

  // Parse and eval `15 & 7 ^ 3` (and has higher precedence: (15&7)^3 = 7^3 = 4)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  inspect(xor_expr.eval_as_int(), content="4")
  assert_true(xor_expr.is_constant())

  // Error test: `x ^ 7` (contains variable, not constant)
  let rest = next_check_point(rest)
  let (xor_expr, rest) = ctx.parse_exclusive_or_expr(rest)
  assert_false(xor_expr.is_constant())
  let r = try? xor_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: `15 ^ y` (contains variable, not constant)
  let rest = next_check_point(rest)
  let (xor_expr, _rest) = ctx.parse_exclusive_or_expr(rest)
  assert_false(xor_expr.is_constant())
  let r = try? xor_expr.eval_as_int()
  assert_true(r is Err(_))
}
