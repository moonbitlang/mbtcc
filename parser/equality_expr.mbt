///|
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
  ...
}

///|
pub enum EqualityExprKind {
  RelationalExpr(RelationalExpr)
  EQExpr(EqualityExpr, RelationalExpr)
  NEExpr(EqualityExpr, RelationalExpr)
} derive(Eq)

///|
///
/// AI DO
pub fn Context::parse_equality_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (EqualityExpr, ArrayView[Token]) raise ParseError {
  ...
}

///|
test "Equality Expr Parse Test" {

}

///|
test "Equality Expr Parse Error Test" {

}
