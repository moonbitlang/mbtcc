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
  ...
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
