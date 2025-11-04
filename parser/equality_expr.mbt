///|
///
/// Equality Expression
///
/// Equality expressions are binary expressions that perform
/// equality or inequality comparisons on relational expressions, yielding a boolean result.
///
/// ## Examples
///
/// ```c
/// a == b;      // Equality
/// x != y;      // Inequality
/// p == NULL;   // Pointer comparison
/// a == b != c; // Multiple operations (left-associative)
/// ```
///
/// ## Grammar (EBNF)
///
/// equality_expression
///   : relational_expression
///   | equality_expression '==' relational_expression
///   | equality_expression '!=' relational_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_equality_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (EqualityExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct EqualityExpr {
  kind : EqualityExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for EqualityExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for EqualityExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// equality expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn EqualityExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    RelationalExpr(relational_expr) => relational_expr.to_string(color~)
    EQExpr(left, right) | NEExpr(left, right) => {
      let op = match self.kind {
        EQExpr(_, _) => "=="
        NEExpr(_, _) => "!="
        _ => ""
      }
      let prefix = if color {
        @color.taint("equality expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "equality expr: \{op} " + "(\{self.ctype})"
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
pub enum EqualityExprKind {
  RelationalExpr(RelationalExpr)
  EQExpr(EqualityExpr, RelationalExpr)
  NEExpr(EqualityExpr, RelationalExpr)
} derive(Eq)

///|
/// Parse an equality expression from the given tokens.
///
/// Returns a tuple containing the parsed EqualityExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a == b;      // Equality
/// x != y;      // Inequality
/// p == NULL;   // Pointer comparison
/// a == b != c; // Multiple operations (left-associative)
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x == y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (equality_expr, rest) = ctx.parse_equality_expr(ctx.tokens)
/// inspect(
///   equality_expr.to_string(color=false),
///   content=(
///     #|equality expr: == (int)
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
/// 1. Parse relational expression fails.
///
///    e.g.,
///
///    ```c
///    == 10  // invalid relational expression before '=='
///    ```
///
/// 2. The operand type is not comparable for equality.
///
///    Note: Unlike relational operators, equality operators can compare
///    more types including pointers to different types, but not struct/union types.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    p1 == p2;  // Invalid use of '==' operator on struct types
///    ```
pub fn Context::parse_equality_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (EqualityExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_relational_expr, rest) = self.parse_relational_expr(tokens)
  let mut equality_expr = EqualityExpr::{
    kind: RelationalExpr(first_relational_expr),
    ctype: first_relational_expr.ctype,
    tokens: first_relational_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("=="), .. } as op_tok, .. rest] => {
      let (right_relational_expr, rest) = self.parse_relational_expr(rest)
      // Check if operands are comparable for equality
      // Equality allows numeric types and pointers, but not structs/unions
      let left_ok = equality_expr.ctype.is_numeric() ||
        equality_expr.ctype.dataKind is Ptr(_)
      let right_ok = right_relational_expr.ctype.is_numeric() ||
        right_relational_expr.ctype.dataKind is Ptr(_)
      if !left_ok {
        let msg = "Invalid left operand to '==': '\{equality_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      if !right_ok {
        let msg = "Invalid right operand to '==': '\{right_relational_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result)
      equality_expr = EqualityExpr::{
        kind: EQExpr(equality_expr, right_relational_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("!="), .. } as op_tok, .. rest] => {
      let (right_relational_expr, rest) = self.parse_relational_expr(rest)
      // Check if operands are comparable for equality
      // Equality allows numeric types and pointers, but not structs/unions
      let left_ok = equality_expr.ctype.is_numeric() ||
        equality_expr.ctype.dataKind is Ptr(_)
      let right_ok = right_relational_expr.ctype.is_numeric() ||
        right_relational_expr.ctype.dataKind is Ptr(_)
      if !left_ok {
        let msg = "Invalid left operand to '!=': '\{equality_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      if !right_ok {
        let msg = "Invalid right operand to '!=': '\{right_relational_expr.ctype}' is not a comparable type"
        raise ParseError(op_tok, msg)
      }
      // Result type is always int (boolean result)
      equality_expr = EqualityExpr::{
        kind: NEExpr(equality_expr, right_relational_expr),
        ctype: CType::int(),
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (equality_expr, rest)
}

///|
test "Equality Expr Parse Test" {
  let color = false
  let code =
    #|x ; x == y ; a != b ; x == 0 ; p != NULL ; x == y != z ; a != b == c ; 
    #|10 == 20 ; 3.14 != 2.0 ; i == j == k ; x < y == z ; a == b < c ;
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
  ..add_var("p", ctype_ptr)
  ..add_var("NULL", ctype_ptr)
  ..add_var("i", ctype_int)
  ..add_var("j", ctype_int)
  ..add_var("k", ctype_int)

  // Parse `x` (no equality operation)
  let (equality_expr, rest) = ctx.parse_equality_expr(ctx.tokens)
  inspect(equality_expr.to_string(color~), content="variable x (int)")
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `x == y`
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-variable x (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `a != b`
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: != (int)
      #|├-variable a (int)
      #|└-variable b (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `x == 0`
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-variable x (int)
      #|└-int literal 0 (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `p != NULL`
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: != (int)
      #|├-variable p (int *)
      #|└-variable NULL (int *)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `x == y != z` (left-associative)
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: != (int)
      #|├-equality expr: == (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `a != b == c` (left-associative)
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-equality expr: != (int)
      #|│ ├-variable a (int)
      #|│ └-variable b (int)
      #|└-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `10 == 20` (with literals)
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-int literal 10 (int)
      #|└-int literal 20 (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `3.14 != 2.0` (with float literals)
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: != (int)
      #|├-double literal 3.14 (double)
      #|└-double literal 2 (double)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `i == j == k` (multiple operations, left-associative)
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-equality expr: == (int)
      #|│ ├-variable i (int)
      #|│ └-variable j (int)
      #|└-variable k (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `x < y == z` (relational has higher precedence)
  let rest = next_check_point(rest)
  let (equality_expr, rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-relational expr: < (int)
      #|│ ├-variable x (int)
      #|│ └-variable y (int)
      #|└-variable z (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )

  // Parse `a == b < c` (relational has higher precedence)
  let rest = next_check_point(rest)
  let (equality_expr, _rest) = ctx.parse_equality_expr(rest)
  inspect(
    equality_expr.to_string(color~),
    content=(
      #|equality expr: == (int)
      #|├-variable a (int)
      #|└-relational expr: < (int)
      #|  ├-variable b (int)
      #|  └-variable c (int)
    ),
  )
  assert_true(
    ctx.parse_equality_expr(equality_expr.tokens) is (re_equality_expr, re_rest) &&
    re_equality_expr == equality_expr &&
    re_rest is [],
  )
}

///|
test "Equality Expr Parse Error Test" {
  // Error test: struct == struct (incompatible types)
  let code_err1 = "p1 == p2"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1.add_var("p1", point_struct)
  ctx_err1.add_var("p2", point_struct)
  let r = try? ctx_err1.parse_equality_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: struct != struct (incompatible types)
  let code_err2 = "p1 != p2"
  let ctx_err2 = Context::new(code=code_err2)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err2.add_var("p1", point_struct)
  ctx_err2.add_var("p2", point_struct)
  let r = try? ctx_err2.parse_equality_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: void == int (incompatible types)
  let code_err3 = "v == x"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("v", CType::void_())
  ctx_err3.add_var("x", CType::int())
  let r = try? ctx_err3.parse_equality_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: int != void (incompatible types)
  let code_err4 = "x != v"
  let ctx_err4 = Context::new(code=code_err4)
  ctx_err4.add_var("x", CType::int())
  ctx_err4.add_var("v", CType::void_())
  let r = try? ctx_err4.parse_equality_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: struct == int (left operand not comparable)
  let code_err5 = "s == i"
  let ctx_err5 = Context::new(code=code_err5)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err5.add_var("s", point_struct)
  ctx_err5.add_var("i", CType::int())
  let r = try? ctx_err5.parse_equality_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: int != struct (right operand not comparable)
  let code_err6 = "i != s"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("i", CType::int())
  ctx_err6.add_var("s", point_struct)
  let r = try? ctx_err6.parse_equality_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}
