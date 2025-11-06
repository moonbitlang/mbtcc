///|
pub struct Expr {
  assign_exprs : Array[AssignExpr]
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Expr with equal(self, other) {
  self.assign_exprs == other.assign_exprs
}

///|
pub fn Context::parse_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (Expr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let assign_exprs = Array::new()
  let (assign_expr, rest) = self.parse_assign_expr(tokens)
  assign_exprs.push(assign_expr)
  let rest = loop rest {
    [{ kind: Comma, .. }, .. rest] => {
      let (assign_expr, rest) = self.parse_assign_expr(rest)
      assign_exprs.push(assign_expr)
      continue rest
    }
    rest => break rest
  }
  let ctype = assign_exprs.last().unwrap().ctype
  let expr = Expr::{
    assign_exprs,
    ctype,
    tokens: init_tokens[0:rest.start_offset() - start_offset],
  }
  (expr, rest)
}

///|
pub fn Expr::is_constant(self : Self) -> Bool {
  for expr in self.assign_exprs {
    if !expr.is_constant() {
      return false
    }
  }
  true
}

///|
pub fn Expr::eval_as_int(self : Self) -> Int raise ParseError {
  if self.assign_exprs.length() == 0 {
    raise ParseError(
      self.tokens[0],
      "Cannot evaluate empty expression as integer",
    )
  }
  // Evaluate the last assign expression
  self.assign_exprs.last().unwrap().eval_as_int()
}

///|
test "Expr Parse Test" {

}

///|
test "Expr Parse Error Test" {

}

///|
test "Expr Eval Test" {

}
