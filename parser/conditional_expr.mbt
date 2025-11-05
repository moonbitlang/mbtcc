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
///
/// Convert From ConditionalExpr, but check all
/// operands are constant expressions
pub struct ConstantExpr {
  kind : ConditionalExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
///
/// Check if all operands are constant
pub fn ConstantExpr::from_conditional_expr(
  expr : ConditionalExpr,
) -> ConstantExpr raise ParseError {
  ...
}

///|
pub fn Context::parse_constant_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (ConstantExpr, ArrayView[Token]) raise ParseError {
  let (cond_expr, rest) = self.parse_conditional_expr(tokens)
  let const_expr = ConstantExpr::from_conditional_expr(cond_expr)
  (const_expr, rest)
}

///|
///
/// All Operands must be Int Type
pub fn ConstantExpr::eval_as_int(self : Self) -> Int raise ParseError {
  raise ParseError(self.tokens[0], "Not implemented yet")
}

///|
test "Conditional Expr Parse Test" {

}

///|
test "Conditional Expr Parse Error Test" {

}
