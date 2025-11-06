///|
pub struct AssignExpr {
  kind : AssignExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AssignExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum AssignExprKind {
  Conditional(ConditionalExpr)
  Assign(UnaryExpr, AssignOp, AssignExpr)
} derive(Eq)

///|
pub fn Context::parse_assign_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AssignExpr, ArrayView[Token]) raise ParseError {
  let (conditional_expr, rest) = self.parse_conditional_expr(tokens)
  guard rest is [{ kind: AssignOp(assign_op), .. } as tok, .. rest] else {
    let assign_expr = AssignExpr::{
      kind: Conditional(conditional_expr),
      ctype: conditional_expr.ctype,
      tokens: conditional_expr.tokens,
    }
    return (assign_expr, rest)
  }
  guard conditional_expr.kind is LogicalOrExpr(e) &&
    e.kind is LogicalAndExpr(e) &&
    e.kind is InclusiveOrExpr(e) &&
    e.kind is ExclusiveOrExpr(e) &&
    e.kind is AndExpr(e) &&
    e.kind is EqualityExpr(e) &&
    e.kind is RelationalExpr(e) &&
    e.kind is ShiftExpr(e) &&
    e.kind is AddiExpr(e) &&
    e.kind is MultiExpr(e) &&
    e.kind is CastExpr(e) else {
    raise ParseError(
      rest[0],
      "Left-hand side of assignment must be a modifiable lvalue",
    )
  }
  let unary_expr = e.unary_expr
  guard unary_expr.is_assignable() else {
    raise ParseError(
      tok, "Left-hand side of assignment must be a modifiable lvalue",
    )
  }
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let assign_op = match assign_op {
    "=" => AssignOp::Assign
    "*=" => MulAssign
    "/=" => DivAssign
    "%=" => ModAssign
    "+=" => AddAssign
    "-=" => SubAssign
    "<<=" => ShlAssign
    ">>=" => ShrAssign
    "&=" => AndAssign
    "^=" => XorAssign
    "|=" => OrAssign
    _ => raise ParseError(rest[0], "Invalid assignment operator")
  }
  let (assign_expr, rest) = self.parse_assign_expr(rest)
  let assign_expr = AssignExpr::{
    kind: Assign(unary_expr, assign_op, assign_expr),
    ctype: assign_expr.ctype, // TODO: once the left type != right type, what type it becomes?
    tokens: tokens[0:rest.start_offset() - start_offset],
  }
  (assign_expr, rest)
}

///|
pub(all) enum AssignOp {
  Assign // =
  MulAssign // *=
  DivAssign // /=
  ModAssign // %=
  AddAssign // +=
  SubAssign // -=
  ShlAssign // <<=
  ShrAssign // >>=
  AndAssign // &=
  XorAssign // ^=
  OrAssign // |=
} derive(Eq)

///|
pub fn AssignExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    Conditional(expr) => expr.is_constant()
    _ => false
  }
}

///|
pub fn AssignExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    Conditional(expr) => expr.eval_as_int()
    _ =>
      raise ParseError(
        self.tokens[0],
        "Cannot evaluate non-constant expression as integer",
      )
  }
}

///|
test "Assign Expr Parse Test" {

}

///|
test "Assign Expr Parse Error Test" {

}

///|
test "Assign Expr Eval Test" {

}
