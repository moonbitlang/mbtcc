///|
///
/// Relational Expression
///
/// Relational expressions are binary expressions that perform
/// comparison operations on shift expressions, yielding a boolean result.
///
/// ## Examples
///
/// ```c
/// a < b;       // Less than
/// x > y;       // Greater than
/// n <= m;      // Less than or equal
/// p >= q;      // Greater than or equal
/// a < b > c;   // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// relational_expression
///   : shift_expression
///   | relational_expression '<' shift_expression
///   | relational_expression '>' shift_expression
///   | relational_expression '<=' shift_expression
///   | relational_expression '>=' shift_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_relational_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (RelationalExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct RelationalExpr {
  kind : RelationalExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for RelationalExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for RelationalExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// relational expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn RelationalExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    ShiftExpr(shift_expr) => shift_expr.to_string(color~)
    LTExpr(left, right)
    | GTExpr(left, right)
    | LEExpr(left, right)
    | GEExpr(left, right) => {
      let op = match self.kind {
        LTExpr(_, _) => "<"
        GTExpr(_, _) => ">"
        LEExpr(_, _) => "<="
        GEExpr(_, _) => ">="
        _ => ""
      }
      let prefix = if color {
        @color.taint("relational expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "relational expr: \{op} " + "(\{self.ctype})"
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
pub enum RelationalExprKind {
  ShiftExpr(ShiftExpr)
  LTExpr(RelationalExpr, ShiftExpr)
  GTExpr(RelationalExpr, ShiftExpr)
  LEExpr(RelationalExpr, ShiftExpr)
  GEExpr(RelationalExpr, ShiftExpr)
} derive(Eq)

///|
/// Parse a relational expression from the given tokens.
///
/// Returns a tuple containing the parsed RelationalExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a < b;       // Less than
/// x > y;       // Greater than
/// n <= m;      // Less than or equal
/// p >= q;      // Greater than or equal
/// a < b < c;   // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x < y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (relational_expr, rest) = ctx.parse_relational_expr(ctx.tokens)
/// inspect(
///   relational_expr.to_string(color=false),
///   content=(
///     #|relational expr: < (int)
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
/// 1. Parse shift expression fails.
///
///    e.g.,
///
///    ```c
///    < 10  // invalid shift expression before '<'
///    ```
///
/// 2. The operand type is not comparable.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    p1 < p2;  // Invalid use of '<' operator on struct types
///    ```
pub fn Context::parse_relational_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (RelationalExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_shift_expr, rest) = self.parse_shift_expr(tokens)
  let mut relational_expr = RelationalExpr::{
    kind: ShiftExpr(first_shift_expr),
    ctype: first_shift_expr.ctype,
    tokens: first_shift_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("<"), .. } as op_tok, .. rest] => {
      let (right_shift_expr, rest) = self.parse_shift_expr(rest)
      // Check if operands are comparable
      if !relational_expr.ctype.is_numeric() &&
        !(relational_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid left operand to '<': '\{relational_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      if !right_shift_expr.ctype.is_numeric() &&
        !(right_shift_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid right operand to '<': '\{right_shift_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result)
      relational_expr = RelationalExpr::{
        kind: LTExpr(relational_expr, right_shift_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator(">"), .. } as op_tok, .. rest] => {
      let (right_shift_expr, rest) = self.parse_shift_expr(rest)
      // Check if operands are comparable
      if !relational_expr.ctype.is_numeric() &&
        !(relational_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid left operand to '>': '\{relational_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      if !right_shift_expr.ctype.is_numeric() &&
        !(right_shift_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid right operand to '>': '\{right_shift_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result)
      relational_expr = RelationalExpr::{
        kind: GTExpr(relational_expr, right_shift_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("<="), .. } as op_tok, .. rest] => {
      let (right_shift_expr, rest) = self.parse_shift_expr(rest)
      // Check if operands are comparable
      if !relational_expr.ctype.is_numeric() &&
        !(relational_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid left operand to '<=': '\{relational_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      if !right_shift_expr.ctype.is_numeric() &&
        !(right_shift_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid right operand to '<=': '\{right_shift_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result)
      relational_expr = RelationalExpr::{
        kind: LEExpr(relational_expr, right_shift_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator(">="), .. } as op_tok, .. rest] => {
      let (right_shift_expr, rest) = self.parse_shift_expr(rest)
      // Check if operands are comparable
      if !relational_expr.ctype.is_numeric() &&
        !(relational_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid left operand to '>=': '\{relational_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      if !right_shift_expr.ctype.is_numeric() &&
        !(right_shift_expr.ctype.dataKind is Ptr(_)) {
        let msg = "Invalid right operand to '>=': '\{right_shift_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result)
      relational_expr = RelationalExpr::{
        kind: GEExpr(relational_expr, right_shift_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (relational_expr, rest)
}

///|
pub fn RelationalExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    ShiftExpr(shift_expr) => shift_expr.is_constant()
    LTExpr(left, right) => left.is_constant() && right.is_constant()
    GTExpr(left, right) => left.is_constant() && right.is_constant()
    LEExpr(left, right) => left.is_constant() && right.is_constant()
    GEExpr(left, right) => left.is_constant() && right.is_constant()
  }
}

///|
pub fn RelationalExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    ShiftExpr(shift_expr) => shift_expr.eval_as_int()
    LTExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      if left_val < right_val {
        1
      } else {
        0
      }
    }
    GTExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      if left_val > right_val {
        1
      } else {
        0
      }
    }
    LEExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      if left_val <= right_val {
        1
      } else {
        0
      }
    }
    GEExpr(left, right) => {
      let left_val = left.eval_as_int()
      let right_val = right.eval_as_int()
      if left_val >= right_val {
        1
      } else {
        0
      }
    }
  }
}

///|
test "Relational Expr Parse Test" {
  let color = false
  let code =
    #|x ; x < y ; a > b ; m <= n ; p >= q ; x < y > z ; a > b <= c ; 
    #|10 < 20 ; 3.14 > 2.0 ; i < j < k ; x + y < z ; a < b + c ;
  let ctx = Context::new(code~, source_file="demo")

  // Setup variables
  let ctype_int = CType::int()
  ctx
  ..add_var("x", ctype_int)
  ..add_var("y", ctype_int)
  ..add_var("a", ctype_int)
  ..add_var("b", ctype_int)
  ..add_var("m", ctype_int)
  ..add_var("n", ctype_int)
  ..add_var("p", ctype_int)
  ..add_var("q", ctype_int)
  ..add_var("z", ctype_int)
  ..add_var("c", ctype_int)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("k", ctype_int)

  // Parse `x` (no relational operation)
  let (relational_expr, rest) = ctx.parse_relational_expr(ctx.tokens)
  inspect(relational_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `x < y`
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: < (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `a > b`
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: > (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `m <= n`
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: <= (int)
      #|├-variable m (int)
      #|└-variable n (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `p >= q`
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: >= (int)
      #|├-variable p (int)
      #|└-variable q (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `x < y > z` (left-associative)
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: > (int)
      #|├-relational expr: < (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `a > b <= c` (left-associative)
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: <= (int)
      #|├-relational expr: > (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `10 < 20` (with literals)
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: < (int)
      #|├-int literal 10 (int)
      #|└-int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `3.14 > 2.0` (with float literals)
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: > (int)
      #|├-double literal 3.14 (double)
      #|└-double literal 2 (double)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `i < j < k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: < (int)
      #|├-relational expr: < (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `x + y < z` (additive has higher precedence)
  let rest = next_check_point(rest)
  let (relational_expr, rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: < (int)
      #|├-additive expr: + (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )

  // Parse `a < b + c` (additive has higher precedence)
  let rest = next_check_point(rest)
  let (relational_expr, _rest) = ctx.parse_relational_expr(rest)
  inspect(
    relational_expr.to_string(color~),
    content=(
      #|relational expr: < (int)
      #|├-variable a (int)
      #|└-additive expr: + (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_relational_expr(relational_expr.tokens)
    is (re_relational_expr, re_rest) &&
    re_relational_expr == relational_expr &&
    re_rest is [],
  )
}

///|
test "Relational Expr Parse Error Test" {
  // Error test: struct < struct (incompatible types)
  let code_err1 = "p1 < p2"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1.add_var("p1", point_struct)
  ctx_err1.add_var("p2", point_struct)
  let r = try? ctx_err1.parse_relational_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: struct > struct (incompatible types)
  let code_err2 = "p1 > p2"
  let ctx_err2 = Context::new(code=code_err2)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err2.add_var("p1", point_struct)
  ctx_err2.add_var("p2", point_struct)
  let r = try? ctx_err2.parse_relational_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: void <= int (incompatible types)
  let code_err3 = "v <= x"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("v", CType::void_())
  ctx_err3.add_var("x", CType::int())
  let r = try? ctx_err3.parse_relational_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int >= void (incompatible types)
  let code_err4 = "x >= v"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("x", CType::int())
  ctx_err4.add_var("v", CType::void_())
  let r = try? ctx_err4.parse_relational_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: struct < int (left operand not comparable)
  let code_err5 = "s < i"
  let ctx_err5 = Context::new(code=code_err5)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err5.add_var("s", point_struct)
  ctx_err5.add_var("i", CType::int())
  let r = try? ctx_err5.parse_relational_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: int > struct (right operand not comparable)
  let code_err6 = "i > s"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("i", CType::int())
  ctx_err6.add_var("s", point_struct)
  let r = try? ctx_err6.parse_relational_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}

///|
test "RelationalExpr Constant Eval Test" {

}
