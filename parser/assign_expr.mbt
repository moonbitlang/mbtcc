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
