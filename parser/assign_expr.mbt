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
  Assign(UnaryExpr, AssignExpr)
  MulAssign(UnaryExpr, AssignExpr)
  DivAssign(UnaryExpr, AssignExpr)
  ModAssign(UnaryExpr, AssignExpr)
  AddAssign(UnaryExpr, AssignExpr)
  SubAssign(UnaryExpr, AssignExpr)
  ShlAssign(UnaryExpr, AssignExpr)
  ShrAssign(UnaryExpr, AssignExpr)
  AndAssign(UnaryExpr, AssignExpr)
  XorAssign(UnaryExpr, AssignExpr)
  OrAssign(UnaryExpr, AssignExpr)
} derive(Eq)

///|
test "Assign Expr Parse Test" {

}
