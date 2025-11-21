///|
///
/// Shift Expression
///
/// Shift expressions are binary expressions that perform
/// bitwise left shift or right shift operations on additive expressions.
///
/// ## Examples
///
/// ```c
/// a << b;      // Left shift
/// x >> y;      // Right shift
/// n << 2;      // Shift left by 2 bits
/// a << b >> c; // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// shift_expression
///   : additive_expression
///   | shift_expression '<<' additive_expression
///   | shift_expression '>>' additive_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_shift_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (ShiftExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct ShiftExpr {
  kind : ShiftExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ShiftExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for ShiftExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// shift expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn ShiftExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    AddiExpr(addi_expr) => addi_expr.to_string(color~)
    ShlExpr(left, right) | ShrExpr(left, right) => {
      let op = match self.kind {
        ShlExpr(_, _) => "<<"
        ShrExpr(_, _) => ">>"
        _ => ""
      }
      let prefix = if color {
        @color.taint("shift expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "shift expr: \{op} " + "(\{self.ctype})"
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
pub enum ShiftExprKind {
  AddiExpr(AddiExpr)
  ShlExpr(ShiftExpr, AddiExpr)
  ShrExpr(ShiftExpr, AddiExpr)
} derive(Eq)

///|
/// Parse a shift expression from the given tokens.
///
/// Returns a tuple containing the parsed ShiftExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a << b;      // Left shift
/// x >> y;      // Right shift
/// n << 2;      // Shift left by 2 bits
/// a << b >> c; // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x << y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (shift_expr, rest) = ctx.parse_shift_expr(ctx.tokens)
/// inspect(
///   shift_expr.to_string(color=false),
///   content=(
///     #|shift expr: << (int)
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
/// 1. Parse additive expression fails.
///
///    e.g.,
///
///    ```c
///    << 10  // invalid additive expression before '<<'
///    ```
///
/// 2. The operand type is not an integer type.
///
///    e.g.,
///    ```c
///    float f;
///    int i;
///    f << i;  // Invalid use of '<<' operator on float type
///    ```
pub fn Context::parse_shift_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ShiftExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_addi_expr, rest) = self.parse_addi_expr(tokens)
  let mut shift_expr = ShiftExpr::{
    kind: AddiExpr(first_addi_expr),
    ctype: first_addi_expr.ctype,
    tokens: first_addi_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("<<"), .. } as op_tok, .. rest] => {
      let (right_addi_expr, rest) = self.parse_addi_expr(rest)
      if !shift_expr.ctype.is_integral() {
        let msg = "Invalid left operand to '<<': '\{shift_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      if !right_addi_expr.ctype.is_integral() {
        let msg = "Invalid right operand to '<<': '\{right_addi_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      shift_expr = ShiftExpr::{
        kind: ShlExpr(shift_expr, right_addi_expr),
        ctype: shift_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator(">>"), .. } as op_tok, .. rest] => {
      let (right_addi_expr, rest) = self.parse_addi_expr(rest)
      if !shift_expr.ctype.is_integral() {
        let msg = "Invalid left operand to '>>': '\{shift_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      if !right_addi_expr.ctype.is_integral() {
        let msg = "Invalid right operand to '>>': '\{right_addi_expr.ctype}' is not an integer type"
        raise ParseError(op_tok, msg)
      }
      shift_expr = ShiftExpr::{
        kind: ShrExpr(shift_expr, right_addi_expr),
        ctype: shift_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (shift_expr, rest)
}

///|
pub fn ShiftExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    AddiExpr(addi_expr) => addi_expr.is_constant()
    ShlExpr(left, right) | ShrExpr(left, right) =>
      left.is_constant() && right.is_constant()
  }
}

///|
pub fn ShiftExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    AddiExpr(addi_expr) => addi_expr.eval_as_int()
    ShlExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      left_val << right_val
    }
    ShrExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      left_val >> right_val
    }
  }
}

///|
test "Shift Expr Parse Test" {
  let color = false
  let code =
    #|x ; x << y ; a >> b ; x << 2 ; x << y >> z ; a >> b << c ; 
    #|10 << 2 ; i << j << k ; x + y << z ; a << b + c ;
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

  // Parse `x` (no shift operation)
  let (shift_expr, rest) = ctx.parse_shift_expr(ctx.tokens)
  inspect(shift_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `x << y`
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `a >> b`
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: >> (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `x << 2`
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-variable x (int)
      #|└-int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `x << y >> z` (left-associative)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: >> (int)
      #|├-shift expr: << (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `a >> b << c` (left-associative)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-shift expr: >> (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `10 << 2` (with literals)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-int literal 10 (int)
      #|└-int literal 2 (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `i << j << k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-shift expr: << (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `x + y << z` (additive has higher precedence)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-additive expr: + (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )

  // Parse `a << b + c` (additive has higher precedence)
  let rest = next_check_point(rest)
  let (shift_expr, _rest) = ctx.parse_shift_expr(rest)
  inspect(
    shift_expr.to_string(color~),
    content=(
      #|shift expr: << (int)
      #|├-variable a (int)
      #|└-additive expr: + (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_shift_expr(shift_expr.tokens) is (re_shift_expr, re_rest) &&
    re_shift_expr == shift_expr &&
    re_rest is [],
  )
}

///|
test "Shift Expr Parse Error Test" {
  // Error test: float << int (left operand is not integer)
  let code_err1 = "f << i"
  let ctx_err1 = Context::new(code=code_err1)
  ctx_err1.add_var("f", CType::float())
  ctx_err1.add_var("i", CType::int())
  let r = try? ctx_err1.parse_shift_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: int << float (right operand is not integer)
  let code_err2 = "i << f"
  let ctx_err2 = Context::new(code=code_err2)
  ctx_err2.add_var("i", CType::int())
  ctx_err2.add_var("f", CType::float())
  let r = try? ctx_err2.parse_shift_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: double >> int (left operand is not integer)
  let code_err3 = "d >> i"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("d", CType::double())
  ctx_err3.add_var("i", CType::int())
  let r = try? ctx_err3.parse_shift_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int >> double (right operand is not integer)
  let code_err4 = "i >> d"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("i", CType::int())
  ctx_err4.add_var("d", CType::double())
  let r = try? ctx_err4.parse_shift_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: pointer << int (pointer is not integer)
  let code_err5 = "p << i"
  let ctx_err5 = Context::new(code=code_err5)
  let int_ptr = CType::int().ptr_to()
  ctx_err5.add_var("p", int_ptr)
  ctx_err5.add_var("i", CType::int())
  let r = try? ctx_err5.parse_shift_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: struct >> int (struct is not integer)
  let code_err6 = "s >> i"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("s", point_struct)
  ctx_err6.add_var("i", CType::int())
  let r = try? ctx_err6.parse_shift_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}

///|
test "ShiftExpr Constant Eval Test" {
  // Test eval_as_int for shift expressions
  let code =
    #|42 ; 8 << 2 ; 64 >> 3 ;
    #|2 << 3 << 1 ; 128 >> 2 >> 1 ; 16 << 1 >> 2 ;
    #|2 + 3 << 2 ; 4 << 10 - 8 ;
    #|x << 2 ; 8 >> y ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())

  // Parse and eval `42` (just an addi expr wrapped in ShiftExpr)
  let (shift_expr, rest) = ctx.parse_shift_expr(ctx.tokens)
  inspect(shift_expr.eval_as_int(), content="42")
  assert_true(shift_expr.is_constant())

  // Parse and eval `8 << 2` (left shift: 8 << 2 = 32)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="32")
  assert_true(shift_expr.is_constant())

  // Parse and eval `64 >> 3` (right shift: 64 >> 3 = 8)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="8")
  assert_true(shift_expr.is_constant())

  // Parse and eval `2 << 3 << 1` (multiple left shifts, left-associative: (2<<3)<<1 = 16<<1 = 32)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="32")
  assert_true(shift_expr.is_constant())

  // Parse and eval `128 >> 2 >> 1` (multiple right shifts, left-associative: (128>>2)>>1 = 32>>1 = 16)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="16")
  assert_true(shift_expr.is_constant())

  // Parse and eval `16 << 1 >> 2` (mixed shifts, left-associative: (16<<1)>>2 = 32>>2 = 8)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="8")
  assert_true(shift_expr.is_constant())

  // Parse and eval `2 + 3 << 2` (additive has higher precedence: (2+3)<<2 = 5<<2 = 20)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="20")
  assert_true(shift_expr.is_constant())

  // Parse and eval `4 << 10 - 8` (additive has higher precedence: 4<<(10-8) = 4<<2 = 16)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  inspect(shift_expr.eval_as_int(), content="16")
  assert_true(shift_expr.is_constant())

  // Error test: `x << 2` (contains variable, not constant)
  let rest = next_check_point(rest)
  let (shift_expr, rest) = ctx.parse_shift_expr(rest)
  assert_false(shift_expr.is_constant())
  let r = try? shift_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: `8 >> y` (contains variable, not constant)
  let rest = next_check_point(rest)
  let (shift_expr, _rest) = ctx.parse_shift_expr(rest)
  assert_false(shift_expr.is_constant())
  let r = try? shift_expr.eval_as_int()
  assert_true(r is Err(_))
}
