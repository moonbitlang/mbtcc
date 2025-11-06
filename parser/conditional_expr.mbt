///|
pub struct ConditionalExpr {
  kind : ConditionalExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for ConditionalExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub enum ConditionalExprKind {
  LogicalOrExpr(LogicalOrExpr)
  ConditionalExpr(LogicalOrExpr, Expr, ConditionalExpr)
} derive(Eq)

///|
pub fn Context::parse_conditional_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ConditionalExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let (logical_or_expr, rest) = self.parse_logical_or_expr(tokens)
  guard rest is [{ kind: Question, .. }, .. rest] else {
    let cond_expr = ConditionalExpr::{
      kind: LogicalOrExpr(logical_or_expr),
      ctype: logical_or_expr.ctype,
      tokens: init_tokens[0:rest.start_offset() - start_offset],
    }
    return (cond_expr, rest)
  }
  let (then_expr, rest) = self.parse_expr(rest)
  guard rest is [{ kind: Colon, .. }, .. rest] else {
    raise ParseError(rest[0], "Expected ':' in conditional expression")
  }
  let (else_expr, rest) = self.parse_conditional_expr(rest)
  let ctype = CType::common_type(then_expr.ctype, else_expr.ctype)
  guard ctype is Some(ctype) else {
    raise ParseError(
      init_tokens[0],
      "Incompatible types in conditional expression",
    )
  }
  let cond_expr = ConditionalExpr::{
    kind: ConditionalExpr(logical_or_expr, then_expr, else_expr),
    ctype,
    tokens: init_tokens[0:rest.start_offset() - start_offset],
  }
  (cond_expr, rest)
}

///|
pub fn ConditionalExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    LogicalOrExpr(expr) => expr.is_constant()
    ConditionalExpr(cond, then_expr, else_expr) =>
      cond.is_constant() && then_expr.is_constant() && else_expr.is_constant()
  }
}

///|
pub fn ConditionalExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    LogicalOrExpr(expr) => expr.eval_as_int()
    ConditionalExpr(cond, then_expr, else_expr) => {
      let cond_val = cond.eval_as_int()
      if cond_val != 0 {
        then_expr.eval_as_int()
      } else {
        else_expr.eval_as_int()
      }
    }
  }
}

///|
test "Conditional Expr Parse Test" {

}

///|
test "Conditional Expr Parse Error Test" {

}
