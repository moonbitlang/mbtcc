///|
///
/// Additive Expression
///
/// Additive expressions are binary expressions that perform
/// addition or subtraction operations on multiplicative expressions.
///
/// ## Examples
///
/// ```c
/// a + b;       // Addition
/// x - y;       // Subtraction
/// a + b - c;   // Multiple operations (left-associative)
/// 10 + 20;     // With literals
/// ```
///
/// ## Grammar (EBNF)
///
/// additive_expression
///   : multiplicative_expression
///   | additive_expression '+' multiplicative_expression
///   | additive_expression '-' multiplicative_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_addi_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (AddiExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct AddiExpr {
  kind : AddiExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AddiExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for AddiExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// additive expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn AddiExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    MultiExpr(multi_expr) => multi_expr.to_string(color~)
    AddExpr(left, right) | SubExpr(left, right) => {
      let op = match self.kind {
        AddExpr(_, _) => "+"
        SubExpr(_, _) => "-"
        _ => ""
      }
      let prefix = if color {
        @color.taint("additive expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "additive expr: \{op} " + "(\{self.ctype})"
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
pub enum AddiExprKind {
  MultiExpr(MultiExpr)
  AddExpr(AddiExpr, MultiExpr)
  SubExpr(AddiExpr, MultiExpr)
} derive(Eq)

///|
/// Parse an additive expression from the given tokens.
///
/// Returns a tuple containing the parsed AddiExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a + b;       // Addition
/// x - y;       // Subtraction
/// a + b - c;   // Multiple operations (left-associative)
/// 10 + 20;     // With literals
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x + y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (addi_expr, rest) = ctx.parse_addi_expr(ctx.tokens)
/// inspect(
///   addi_expr.to_string(color=false),
///   content=(
///     #|additive expr: + (int)
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
/// 1. Parse multiplicative expression fails.
///
///    e.g.,
///
///    ```c
///    + 10  // invalid multiplicative expression before '+'
///    ```
///
/// 2. The operand type is not compatible with the additive operator.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    p1 + p2;  // Invalid use of '+' operator on struct types
///    ```
pub fn Context::parse_addi_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (AddiExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_multi_expr, rest) = self.parse_multi_expr(tokens)
  let mut addi_expr = AddiExpr::{
    kind: MultiExpr(first_multi_expr),
    ctype: first_multi_expr.ctype,
    tokens: first_multi_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("+"), .. } as op_tok, .. rest] => {
      let (right_multi_expr, rest) = self.parse_multi_expr(rest)
      let ctype = match
        addi_expr.ctype.additive_result_type(right_multi_expr.ctype, "+") {
        Some(t) => t
        None => {
          let msg = "Invalid operands to '+': '\{addi_expr.ctype}' and '\{right_multi_expr.ctype}'"
          raise ParseError(op_tok, msg)
        }
      }
      addi_expr = AddiExpr::{
        kind: AddExpr(addi_expr, right_multi_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("-"), .. } as op_tok, .. rest] => {
      let (right_multi_expr, rest) = self.parse_multi_expr(rest)
      let ctype = match
        addi_expr.ctype.additive_result_type(right_multi_expr.ctype, "-") {
        Some(t) => t
        None => {
          let msg = "Invalid operands to '-': '\{addi_expr.ctype}' and '\{right_multi_expr.ctype}'"
          raise ParseError(op_tok, msg)
        }
      }
      addi_expr = AddiExpr::{
        kind: SubExpr(addi_expr, right_multi_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (addi_expr, rest)
}

///|
pub fn AddiExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    MultiExpr(multi_expr) => multi_expr.is_constant()
    AddExpr(left, right) => left.is_constant() && right.is_constant()
    SubExpr(left, right) => left.is_constant() && right.is_constant()
  }
}

///|
pub fn AddiExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    MultiExpr(multi_expr) => multi_expr.eval_as_int()
    AddExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      left_val + right_val
    }
    SubExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      left_val - right_val
    }
  }
}

///|
test "Additive Expr Parse Test" {
  let color = false
  let code =
    #|x ; x + y ; a - b ; x + y - z ; a - b + c ; 
    #|10 + 20 ; 3.14 - 2.0 ; i + j + k ; x * y + z ; a + b * c ;
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

  // Parse `x` (no additive operation)
  let (addi_expr, rest) = ctx.parse_addi_expr(ctx.tokens)
  inspect(addi_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `x + y`
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `a - b`
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: - (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `x + y - z` (left-associative)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: - (int)
      #|├-additive expr: + (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `a - b + c` (left-associative)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-additive expr: - (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `10 + 20` (with literals)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-int literal 10 (int)
      #|└-int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `3.14 - 2.0` (with float literals)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: - (double)
      #|├-double literal 3.14 (double)
      #|└-double literal 2 (double)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `i + j + k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-additive expr: + (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `x * y + z` (multiplicative has higher precedence)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-multiplicative expr: * (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )

  // Parse `a + b * c` (multiplicative has higher precedence)
  let rest = next_check_point(rest)
  let (addi_expr, _rest) = ctx.parse_addi_expr(rest)
  inspect(
    addi_expr.to_string(color~),
    content=(
      #|additive expr: + (int)
      #|├-variable a (int)
      #|└-multiplicative expr: * (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_addi_expr(addi_expr.tokens) is (re_addi_expr, re_rest) &&
    re_addi_expr == addi_expr &&
    re_rest is [],
  )
}

///|
test "Additive Expr Error Test" {
  // Error test: struct + struct (incompatible types)
  let code_err1 = "p1 + p2"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1.add_var("p1", point_struct)
  ctx_err1.add_var("p2", point_struct)
  let r = try? ctx_err1.parse_addi_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: struct - struct (incompatible types)
  let code_err2 = "p1 - p2"
  let ctx_err2 = Context::new(code=code_err2)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err2.add_var("p1", point_struct)
  ctx_err2.add_var("p2", point_struct)
  let r = try? ctx_err2.parse_addi_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: void + int (incompatible types)
  let code_err3 = "v + x"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("v", CType::void_())
  ctx_err3.add_var("x", CType::int())
  let r = try? ctx_err3.parse_addi_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: pointer + pointer (invalid addition)
  let code_err4 = "p + q"
  let ctx_err4 = Context::new(code=code_err4)
  let int_ptr = CType::int().ptr_to()
  ctx_err4.add_var("p", int_ptr)
  ctx_err4.add_var("q", int_ptr)
  let r = try? ctx_err4.parse_addi_expr(ctx_err4.tokens)
  assert_true(r is Err(_))
}

///|
test "Additive Expr Constant Eval Test" {
  // Test eval_as_int for additive expressions
  let code =
    #|42 ; 10 + 20 ; 50 - 15 ;
    #|3 + 4 + 5 ; 100 - 20 - 30 ; 10 + 5 - 3 ;
    #|2 * 3 + 4 ; 10 + 5 * 2 ; 20 - 4 * 3 ;
    #|x + 5 ; 10 - y ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())

  // Parse and eval `42` (just a multi expr wrapped in AddiExpr)
  let (addi_expr, rest) = ctx.parse_addi_expr(ctx.tokens)
  inspect(addi_expr.eval_as_int(), content="42")
  assert_true(addi_expr.is_constant())

  // Parse and eval `10 + 20` (addition)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="30")
  assert_true(addi_expr.is_constant())

  // Parse and eval `50 - 15` (subtraction)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="35")
  assert_true(addi_expr.is_constant())

  // Parse and eval `3 + 4 + 5` (multiple additions, left-associative: (3+4)+5 = 7+5 = 12)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="12")
  assert_true(addi_expr.is_constant())

  // Parse and eval `100 - 20 - 30` (multiple subtractions, left-associative: (100-20)-30 = 80-30 = 50)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="50")
  assert_true(addi_expr.is_constant())

  // Parse and eval `10 + 5 - 3` (mixed operations, left-associative: (10+5)-3 = 15-3 = 12)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="12")
  assert_true(addi_expr.is_constant())

  // Parse and eval `2 * 3 + 4` (multiplication has higher precedence: (2*3)+4 = 6+4 = 10)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="10")
  assert_true(addi_expr.is_constant())

  // Parse and eval `10 + 5 * 2` (multiplication has higher precedence: 10+(5*2) = 10+10 = 20)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="20")
  assert_true(addi_expr.is_constant())

  // Parse and eval `20 - 4 * 3` (multiplication has higher precedence: 20-(4*3) = 20-12 = 8)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  inspect(addi_expr.eval_as_int(), content="8")
  assert_true(addi_expr.is_constant())

  // Error test: `x + 5` (contains variable, not constant)
  let rest = next_check_point(rest)
  let (addi_expr, rest) = ctx.parse_addi_expr(rest)
  assert_false(addi_expr.is_constant())
  let r = try? addi_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: `10 - y` (contains variable, not constant)
  let rest = next_check_point(rest)
  let (addi_expr, _rest) = ctx.parse_addi_expr(rest)
  assert_false(addi_expr.is_constant())
  let r = try? addi_expr.eval_as_int()
  assert_true(r is Err(_))
}
