///|
fn CodeGenContext::evaluate_constant_conditional(
  self : Self,
  cond_expr : ConditionalExpr,
) -> Int raise CodeGenError {
  let { expr, select } = cond_expr
  if select is Some(_) {
    raise CodeGenError::UnSupportFeature(
      "Conditional expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_logical_or(expr)
}

///|
fn CodeGenContext::evaluate_constant_logical_or(
  self : Self,
  log_or_expr : LogicalOrExpr,
) -> Int raise CodeGenError {
  let { exprs } = log_or_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex logical expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_logical_and(exprs[0])
}

///|
fn CodeGenContext::evaluate_constant_logical_and(
  self : Self,
  log_and_expr : LogicalAndExpr,
) -> Int raise CodeGenError {
  let { exprs } = log_and_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_inclusive_or(e) })
  let result = loop expr_vals {
    [v1, v2, .. rest] => continue [(v1 != 0 && v2 != 0).to_int(), ..rest]
    [v] => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_inclusive_or(
  self : Self,
  incl_or_expr : InclusiveOrExpr,
) -> Int raise CodeGenError {
  let { exprs } = incl_or_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_exclusive_or(e) })
  let result = loop expr_vals {
    [v1, v2, .. rest] => continue [v1 | v2, ..rest]
    [v] => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_exclusive_or(
  self : Self,
  excl_or_expr : ExclusiveOrExpr,
) -> Int raise CodeGenError {
  let { exprs } = excl_or_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_and(e) })
  let result = loop expr_vals {
    [v1, v2, .. rest] => continue [v1 ^ v2, ..rest]
    [v] => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_and(
  self : Self,
  and_expr : AndExpr,
) -> Int raise CodeGenError {
  let { exprs } = and_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_equality(e) })
  let result = loop expr_vals {
    [v1, v2, .. rest] => continue [v1 & v2, ..rest]
    [v] => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_equality(
  self : Self,
  eq_expr : EqualityExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = eq_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_relational(e) })
  let result = loop (expr_vals, ops[:]) {
    ([v1, v2, .. rest], [EQ, .. ops]) =>
      continue ([(v1 == v2).to_int(), ..rest], ops)
    ([v1, v2, .. rest], [NE, .. ops]) =>
      continue ([(v1 != v2).to_int(), ..rest], ops)
    ([v], []) => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions and operators")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_relational(
  self : Self,
  rel_expr : RelationalExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = rel_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_shift(e) })
  let result = loop (expr_vals, ops[:]) {
    ([v1, v2, .. rest], [LT, .. ops]) =>
      continue ([(v1 < v2).to_int(), ..rest], ops)
    ([v1, v2, .. rest], [GT, .. ops]) =>
      continue ([(v1 > v2).to_int(), ..rest], ops)
    ([v1, v2, .. rest], [LE, .. ops]) =>
      continue ([(v1 <= v2).to_int(), ..rest], ops)
    ([v1, v2, .. rest], [GE, .. ops]) =>
      continue ([(v1 >= v2).to_int(), ..rest], ops)
    ([v], []) => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions and operators")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_shift(
  self : Self,
  shift_expr : ShiftExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = shift_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_addsub(e) })
  let result = loop (expr_vals, ops[:]) {
    ([v1, v2, .. rest], [Shl, .. ops]) => continue ([v1 << v2, ..rest], ops)
    ([v1, v2, .. rest], [Shr, .. ops]) => continue ([v1 >> v2, ..rest], ops)
    ([v], []) => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions and operators")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_addsub(
  self : Self,
  add_expr : AddSubExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = add_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_mult(e) })
  let result = loop (expr_vals, ops[:]) {
    ([v1, v2, .. rest], [Add, .. ops]) => continue ([v1 + v2, ..rest], ops)
    ([v1, v2, .. rest], [Sub, .. ops]) => continue ([v1 - v2, ..rest], ops)
    ([v], []) => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions and operators")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_mult(
  self : Self,
  mult_expr : MultExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = mult_expr
  let expr_vals = exprs.map(fn(e) { self.evaluate_constant_cast(e) })
  let result = loop (expr_vals, ops[:]) {
    ([v1, v2, .. rest], [Mult, .. ops]) => continue ([v1 * v2, ..rest], ops)
    ([_, 0, ..], [Div, ..]) =>
      raise CodeGenError::SyntaxError("Division by zero in constant expression")
    ([v1, v2, .. rest], [Div, .. ops]) => continue ([v1 / v2, ..rest], ops)
    ([_, 0, ..], [Mod, ..]) =>
      raise CodeGenError::SyntaxError("Modulo by zero in constant expression")
    ([v1, v2, .. rest], [Mod, .. ops]) => continue ([v1 % v2, ..rest], ops)
    ([v], []) => break v
    _ => raise CodeGenError::SyntaxError("Mismatched expressions and operators")
  }
  result
}

///|
fn CodeGenContext::evaluate_constant_cast(
  self : Self,
  cast_expr : CastExpr,
) -> Int raise CodeGenError {
  match cast_expr {
    UnaryExpr(unary_expr) => self.evaluate_constant_unary(unary_expr)
    Cast(_, _) =>
      raise CodeGenError::UnSupportFeature(
        "Cast expressions not supported in array sizes",
      )
  }
}

///|
fn CodeGenContext::evaluate_constant_unary(
  self : Self,
  unary_expr : UnaryExpr,
) -> Int raise CodeGenError {
  if !unary_expr.prefix.is_empty() {
    raise CodeGenError::UnSupportFeature(
      "Unary prefix operators not supported in array sizes",
    )
  }
  self.evaluate_constant_unary_body(unary_expr.body)
}

///|
fn CodeGenContext::evaluate_constant_unary_body(
  self : Self,
  unary_body : UnaryExprBody,
) -> Int raise CodeGenError {
  match unary_body {
    PostFix(postfix_expr) => self.evaluate_constant_postfix(postfix_expr)
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only simple postfix expressions supported in array sizes",
      )
  }
}

///|
fn CodeGenContext::evaluate_constant_postfix(
  self : Self,
  post_expr : PostFixExpr,
) -> Int raise CodeGenError {
  if !post_expr.suffixes.is_empty() {
    raise CodeGenError::UnSupportFeature(
      "Postfix operators not supported in array sizes",
    )
  }
  match post_expr.head {
    Left(prim_expr) => self.evaluate_constant_primary(prim_expr)
    Right(_) =>
      raise CodeGenError::UnSupportFeature(
        "Compound literals not supported in array sizes",
      )
  }
}

///|
fn CodeGenContext::evaluate_constant_primary(
  self : Self,
  prim_expr : PrimExpr,
) -> Int raise CodeGenError {
  match prim_expr {
    Constant(constant) =>
      match constant {
        Int(value) => value
        Long(value) => value.to_int()
        UInt(value) => value.reinterpret_as_int()
        ULong(value) => value.reinterpret_as_int64().to_int()
        _ =>
          raise CodeGenError::UnSupportFeature(
            "Only integer constants supported in array sizes",
          )
      }
    Identifier(name) =>
      // Check if it's a macro constant
      match self.typedef_env.get(name) {
        Some(Type::Int(value)) => value
        Some(Type::UInt(value)) => value
        Some(_) =>
          raise CodeGenError::SyntaxError(
            "Identifier '\{name}' does not evaluate to an integer constant",
          )
        None =>
          raise CodeGenError::SyntaxError(
            "Undefined identifier '\{name}' in constant expression",
          )
      }
    ParenExpr(expr) => {
      if expr.exprs.length() != 1 {
        raise CodeGenError::UnSupportFeature(
          "Complex parenthesized expressions not supported in array sizes",
        )
      }
      self.evaluate_constant_expr(expr.exprs[0])
    }
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only integer constants and identifiers supported in array sizes",
      )
  }
}
