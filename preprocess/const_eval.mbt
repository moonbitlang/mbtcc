///|
using @lexer {type TokenKind}

///|
priv enum PrimExpr {
  Int(Int)
  UInt(UInt)
  Long(Int64)
  LongLong(Int64)
  ULong(UInt64)
  ULongLong(UInt64)
  Paren(ConstantExpr)
}

///|
fn parse_prim_expr(
  tokens : ArrayView[Token],
) -> (PrimExpr, ArrayView[Token]) raise PreprecessError {
  match tokens {
    [{ kind: TokenKind::Int(value), .. }, .. rest] => (Int(value), rest)
    [{ kind: TokenKind::UInt(value), .. }, .. rest] => (UInt(value), rest)
    [{ kind: TokenKind::Long(value), .. }, .. rest] => (Long(value), rest)
    [{ kind: TokenKind::LongLong(value), .. }, .. rest] =>
      (LongLong(value), rest)
    [{ kind: TokenKind::ULong(value), .. }, .. rest] => (ULong(value), rest)
    [{ kind: TokenKind::ULongLong(value), .. }, .. rest] =>
      (ULongLong(value), rest)
    [{ kind: TokenKind::Bracket('('), .. }, .. rest] => {
      let (expr, rest) = parse_constant_expr(rest)
      guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
        raise InvalidConstExprToken(
          rest[0],
          "Expected ')' in constant expression, got \{rest[0].kind}",
        )
      }
      (Paren(expr), rest)
    }
    [tok, ..] =>
      raise InvalidConstExprToken(
        tok,
        "Expected constant expression, got \{tok.kind}",
      )
    [] =>
      raise InvalidConstExprToken(
        tokens[0],
        "Unexpected end of tokens in constant expression",
      )
  }
}

///|
fn PrimExpr::eval(self : PrimExpr) -> Int64 {
  match self {
    Int(value) => value.to_int64()
    UInt(value) => value.to_int64()
    Long(value) => value
    LongLong(value) => value
    ULong(value) => value.reinterpret_as_int64()
    ULongLong(value) => value.reinterpret_as_int64()
    Paren(expr) => expr.eval()
  }
}

///|
priv enum UnaryExpr {
  Prim(PrimExpr)
  Negate(UnaryExpr)
  BitNot(UnaryExpr)
  LogicalNot(UnaryExpr)
}

///|
fn parse_unary_expr(
  tokens : ArrayView[Token],
) -> (UnaryExpr, ArrayView[Token]) raise PreprecessError {
  match tokens {
    [{ kind: Operator("-"), .. }, .. rest] => {
      let (inner, rest) = parse_unary_expr(rest)
      (Negate(inner), rest)
    }
    [{ kind: Operator("~"), .. }, .. rest] => {
      let (inner, rest) = parse_unary_expr(rest)
      (BitNot(inner), rest)
    }
    [{ kind: Operator("!"), .. }, .. rest] => {
      let (inner, rest) = parse_unary_expr(rest)
      (LogicalNot(inner), rest)
    }
    [{ kind: Operator("+"), .. }, .. rest] =>
      // Unary plus, just parse the inner expression
      parse_unary_expr(rest)
    _ => {
      let (prim, rest) = parse_prim_expr(tokens)
      (Prim(prim), rest)
    }
  }
}

///|
fn UnaryExpr::eval(self : UnaryExpr) -> Int64 {
  match self {
    Prim(expr) => expr.eval()
    Negate(expr) => -expr.eval()
    BitNot(expr) => expr.eval().lnot()
    LogicalNot(expr) => (expr.eval() == 0).to_int64()
  }
}

///|
priv enum MultiExpr {
  Unary(UnaryExpr)
  Mul(MultiExpr, UnaryExpr)
  Div(MultiExpr, UnaryExpr)
  Mod(MultiExpr, UnaryExpr)
}

///|
fn parse_multi_expr(
  tokens : ArrayView[Token],
) -> (MultiExpr, ArrayView[Token]) raise PreprecessError {
  let (first_unary, rest) = parse_unary_expr(tokens)
  let mut multi_expr = Unary(first_unary)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("*"), .. }, .. rest] => {
      let (right_unary, rest) = parse_unary_expr(rest)
      multi_expr = Mul(multi_expr, right_unary)
      continue rest
    }
    [{ kind: TokenKind::Operator("/"), .. }, .. rest] => {
      let (right_unary, rest) = parse_unary_expr(rest)
      multi_expr = Div(multi_expr, right_unary)
      continue rest
    }
    [{ kind: TokenKind::Operator("%"), .. }, .. rest] => {
      let (right_unary, rest) = parse_unary_expr(rest)
      multi_expr = Mod(multi_expr, right_unary)
      continue rest
    }
    rest => break rest
  }
  (multi_expr, rest)
}

///|
fn MultiExpr::eval(self : MultiExpr) -> Int64 {
  match self {
    Unary(expr) => expr.eval()
    Mul(left, right) => left.eval() * right.eval()
    Div(left, right) => left.eval() / right.eval()
    Mod(left, right) => left.eval() % right.eval()
  }
}

///|
priv enum AddiExpr {
  Multi(MultiExpr)
  Add(AddiExpr, MultiExpr)
  Sub(AddiExpr, MultiExpr)
}

///|
fn parse_addi_expr(
  tokens : ArrayView[Token],
) -> (AddiExpr, ArrayView[Token]) raise PreprecessError {
  let (first_multi, rest) = parse_multi_expr(tokens)
  let mut addi_expr = Multi(first_multi)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("+"), .. }, .. rest] => {
      let (right_multi, rest) = parse_multi_expr(rest)
      addi_expr = Add(addi_expr, right_multi)
      continue rest
    }
    [{ kind: TokenKind::Operator("-"), .. }, .. rest] => {
      let (right_multi, rest) = parse_multi_expr(rest)
      addi_expr = Sub(addi_expr, right_multi)
      continue rest
    }
    rest => break rest
  }
  (addi_expr, rest)
}

///|
fn AddiExpr::eval(self : AddiExpr) -> Int64 {
  match self {
    Multi(expr) => expr.eval()
    Add(left, right) => left.eval() + right.eval()
    Sub(left, right) => left.eval() - right.eval()
  }
}

///|
priv enum ShiftExpr {
  Addi(AddiExpr)
  ShlExpr(ShiftExpr, AddiExpr)
  ShrExpr(ShiftExpr, AddiExpr)
}

///|
fn parse_shift_expr(
  tokens : ArrayView[Token],
) -> (ShiftExpr, ArrayView[Token]) raise PreprecessError {
  let (first_addi, rest) = parse_addi_expr(tokens)
  let mut shift_expr = Addi(first_addi)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("<<"), .. }, .. rest] => {
      let (right_addi, rest) = parse_addi_expr(rest)
      shift_expr = ShlExpr(shift_expr, right_addi)
      continue rest
    }
    [{ kind: TokenKind::Operator(">>"), .. }, .. rest] => {
      let (right_addi, rest) = parse_addi_expr(rest)
      shift_expr = ShrExpr(shift_expr, right_addi)
      continue rest
    }
    rest => break rest
  }
  (shift_expr, rest)
}

///|
fn ShiftExpr::eval(self : ShiftExpr) -> Int64 {
  match self {
    Addi(expr) => expr.eval()
    ShlExpr(left, right) => left.eval() << right.eval().to_int()
    ShrExpr(left, right) => left.eval() >> right.eval().to_int()
  }
}

///|
priv enum RelationalExpr {
  Shift(ShiftExpr)
  LTExpr(RelationalExpr, ShiftExpr)
  GTExpr(RelationalExpr, ShiftExpr)
  LEExpr(RelationalExpr, ShiftExpr)
  GEExpr(RelationalExpr, ShiftExpr)
}

///|
fn parse_relational_expr(
  tokens : ArrayView[Token],
) -> (RelationalExpr, ArrayView[Token]) raise PreprecessError {
  let (first_shift, rest) = parse_shift_expr(tokens)
  let mut rel_expr = Shift(first_shift)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("<"), .. }, .. rest] => {
      let (right_shift, rest) = parse_shift_expr(rest)
      rel_expr = LTExpr(rel_expr, right_shift)
      continue rest
    }
    [{ kind: TokenKind::Operator(">"), .. }, .. rest] => {
      let (right_shift, rest) = parse_shift_expr(rest)
      rel_expr = GTExpr(rel_expr, right_shift)
      continue rest
    }
    [{ kind: TokenKind::Operator("<="), .. }, .. rest] => {
      let (right_shift, rest) = parse_shift_expr(rest)
      rel_expr = LEExpr(rel_expr, right_shift)
      continue rest
    }
    [{ kind: TokenKind::Operator(">="), .. }, .. rest] => {
      let (right_shift, rest) = parse_shift_expr(rest)
      rel_expr = GEExpr(rel_expr, right_shift)
      continue rest
    }
    _ as rest => break rest
  }
  (rel_expr, rest)
}

///|
fn RelationalExpr::eval(self : RelationalExpr) -> Int64 {
  match self {
    Shift(expr) => expr.eval()
    LTExpr(left, right) => (left.eval() < right.eval()).to_int64()
    GTExpr(left, right) => (left.eval() > right.eval()).to_int64()
    LEExpr(left, right) => (left.eval() <= right.eval()).to_int64()
    GEExpr(left, right) => (left.eval() >= right.eval()).to_int64()
  }
}

///|
priv enum EqualityExpr {
  Relational(RelationalExpr)
  EQExpr(EqualityExpr, RelationalExpr)
  NEExpr(EqualityExpr, RelationalExpr)
}

///|
fn parse_equality_expr(
  tokens : ArrayView[Token],
) -> (EqualityExpr, ArrayView[Token]) raise PreprecessError {
  let (first_rel, rest) = parse_relational_expr(tokens)
  let mut eq_expr = Relational(first_rel)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("=="), .. }, .. rest] => {
      let (right_rel, rest) = parse_relational_expr(rest)
      eq_expr = EQExpr(eq_expr, right_rel)
      continue rest
    }
    [{ kind: TokenKind::Operator("!="), .. }, .. rest] => {
      let (right_rel, rest) = parse_relational_expr(rest)
      eq_expr = NEExpr(eq_expr, right_rel)
      continue rest
    }
    _ as rest => break rest
  }
  (eq_expr, rest)
}

///|
fn EqualityExpr::eval(self : EqualityExpr) -> Int64 {
  match self {
    Relational(expr) => expr.eval()
    EQExpr(left, right) => (left.eval() == right.eval()).to_int64()
    NEExpr(left, right) => (left.eval() != right.eval()).to_int64()
  }
}

///|
priv enum AndExpr {
  Equality(EqualityExpr)
  AndExpr(AndExpr, EqualityExpr)
}

///|
fn parse_and_expr(
  tokens : ArrayView[Token],
) -> (AndExpr, ArrayView[Token]) raise PreprecessError {
  let (first_eq, rest) = parse_equality_expr(tokens)
  let mut and_expr = Equality(first_eq)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("&"), .. }, .. rest] => {
      let (right_eq, rest) = parse_equality_expr(rest)
      and_expr = AndExpr(and_expr, right_eq)
      continue rest
    }
    _ as rest => break rest
  }
  (and_expr, rest)
}

///|
fn AndExpr::eval(self : AndExpr) -> Int64 {
  match self {
    Equality(expr) => expr.eval()
    AndExpr(left, right) => left.eval() & right.eval()
  }
}

///|
priv enum ExclusiveOrExpr {
  And(AndExpr)
  XorExpr(ExclusiveOrExpr, AndExpr)
}

///|
fn parse_exclusive_or_expr(
  tokens : ArrayView[Token],
) -> (ExclusiveOrExpr, ArrayView[Token]) raise PreprecessError {
  let (first_and, rest) = parse_and_expr(tokens)
  let mut xor_expr = And(first_and)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("^"), .. }, .. rest] => {
      let (right_and, rest) = parse_and_expr(rest)
      xor_expr = XorExpr(xor_expr, right_and)
      continue rest
    }
    _ as rest => break rest
  }
  (xor_expr, rest)
}

///|
fn ExclusiveOrExpr::eval(self : ExclusiveOrExpr) -> Int64 {
  match self {
    And(expr) => expr.eval()
    XorExpr(left, right) => left.eval() ^ right.eval()
  }
}

///|
priv enum InclusiveOrExpr {
  ExclusiveOr(ExclusiveOrExpr)
  OrExpr(InclusiveOrExpr, ExclusiveOrExpr)
}

///|
fn parse_inclusive_or_expr(
  tokens : ArrayView[Token],
) -> (InclusiveOrExpr, ArrayView[Token]) raise PreprecessError {
  let (first_xor, rest) = parse_exclusive_or_expr(tokens)
  let mut or_expr = ExclusiveOr(first_xor)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("|"), .. }, .. rest] => {
      let (right_xor, rest) = parse_exclusive_or_expr(rest)
      or_expr = OrExpr(or_expr, right_xor)
      continue rest
    }
    _ as rest => break rest
  }
  (or_expr, rest)
}

///|
fn InclusiveOrExpr::eval(self : InclusiveOrExpr) -> Int64 {
  match self {
    ExclusiveOr(expr) => expr.eval()
    OrExpr(left, right) => left.eval() | right.eval()
  }
}

///|
priv enum LogicalAndExpr {
  InclusiveOr(InclusiveOrExpr)
  LogicalAndExpr(LogicalAndExpr, InclusiveOrExpr)
}

///|
fn parse_logical_and_expr(
  tokens : ArrayView[Token],
) -> (LogicalAndExpr, ArrayView[Token]) raise PreprecessError {
  let (first_or, rest) = parse_inclusive_or_expr(tokens)
  let mut and_expr = InclusiveOr(first_or)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("&&"), .. }, .. rest] => {
      let (right_or, rest) = parse_inclusive_or_expr(rest)
      and_expr = LogicalAndExpr(and_expr, right_or)
      continue rest
    }
    _ as rest => break rest
  }
  (and_expr, rest)
}

///|
fn LogicalAndExpr::eval(self : LogicalAndExpr) -> Int64 {
  match self {
    InclusiveOr(expr) => expr.eval()
    LogicalAndExpr(left, right) =>
      (left.eval() != 0 && right.eval() != 0).to_int64()
  }
}

///|
priv enum LogicalOrExpr {
  LogicalAnd(LogicalAndExpr)
  LogicalOrExpr(LogicalOrExpr, LogicalAndExpr)
}

///|
fn parse_logical_or_expr(
  tokens : ArrayView[Token],
) -> (LogicalOrExpr, ArrayView[Token]) raise PreprecessError {
  let (first_and, rest) = parse_logical_and_expr(tokens)
  let mut or_expr = LogicalAnd(first_and)
  let rest = loop rest {
    [{ kind: TokenKind::Operator("||"), .. }, .. rest] => {
      let (right_and, rest) = parse_logical_and_expr(rest)
      or_expr = LogicalOrExpr(or_expr, right_and)
      continue rest
    }
    _ as rest => break rest
  }
  (or_expr, rest)
}

///|
fn LogicalOrExpr::eval(self : LogicalOrExpr) -> Int64 {
  match self {
    LogicalAnd(expr) => expr.eval()
    LogicalOrExpr(left, right) =>
      (left.eval() != 0 || right.eval() != 0).to_int64()
  }
}

///|
priv enum ConstantExpr {
  LogicalOr(LogicalOrExpr)
  ConstantExpr(LogicalOrExpr, ConstantExpr, ConstantExpr)
}

///|
fn parse_constant_expr(
  tokens : ArrayView[Token],
) -> (ConstantExpr, ArrayView[Token]) raise PreprecessError {
  let (cond, rest) = parse_logical_or_expr(tokens)
  match rest {
    [{ kind: TokenKind::Question, .. }, .. rest] => {
      let (then_expr, rest) = parse_constant_expr(rest)
      match rest {
        [{ kind: TokenKind::Colon, .. }, .. rest] => {
          let (else_expr, rest) = parse_constant_expr(rest)
          (ConstantExpr(cond, then_expr, else_expr), rest)
        }
        [tok, ..] =>
          raise InvalidConstExprToken(
            tok,
            "Expected ':' in ternary operator, got \{tok.kind}",
          )
        [] =>
          raise InvalidConstExprToken(
            tokens[0],
            "Unexpected end of tokens, expected ':' in ternary operator",
          )
      }
    }
    _ => (LogicalOr(cond), rest)
  }
}

///|
fn ConstantExpr::eval(self : ConstantExpr) -> Int64 {
  match self {
    LogicalOr(expr) => expr.eval()
    ConstantExpr(cond, then_expr, else_expr) =>
      if cond.eval() != 0 {
        then_expr.eval()
      } else {
        else_expr.eval()
      }
  }
}

///|
test "const_eval" {
  fn skip_semi(tokens : ArrayView[Token]) -> ArrayView[Token] {
    loop tokens {
      [{ kind: Semi, .. }, .. rest] => break rest
      [_, .. rest] => continue rest
      [] as tokens => break tokens
    }
  }

  let code =
    #|42 ; -5 ; ~0 ; !0 ; 1 + 2 ; 3 * 4 ; 2 + 3 * 4 ; (2 + 3) * 4 ;
    #|5 > 3 ; 5 == 5 ; 1 && 0 ; 1 || 0 ; 12 & 10 ; 12 | 10 ; 12 ^ 10 ;
    #|1 << 3 ; 8 >> 2 ; 1 ? 10 : 20 ; 0 ? 10 : 20 ; 1 ? (2 ? 3 : 4) : 5 ;
    #|20 / 4 ; 17 % 5 ;
  let ctx = @lexer.Context::new(code~, source_file="test.c")
  let _ = ctx.tokenize()

  // Parse and eval `42`
  let (expr, rest) = parse_constant_expr(ctx.tokens[:])
  inspect(expr.eval(), content="42")

  // Parse and eval `-5`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="-5")

  // Parse and eval `~0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="-1")

  // Parse and eval `!0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="1")

  // Parse and eval `1 + 2`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="3")

  // Parse and eval `3 * 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="12")

  // Parse and eval `2 + 3 * 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="14")

  // Parse and eval `(2 + 3) * 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="20")

  // Parse and eval `5 > 3`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="1")

  // Parse and eval `5 == 5`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="1")

  // Parse and eval `1 && 0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="0")

  // Parse and eval `1 || 0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="1")

  // Parse and eval `12 & 10`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="8")

  // Parse and eval `12 | 10`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="14")

  // Parse and eval `12 ^ 10`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="6")

  // Parse and eval `1 << 3`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="8")

  // Parse and eval `8 >> 2`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="2")

  // Parse and eval `1 ? 10 : 20`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="10")

  // Parse and eval `0 ? 10 : 20`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="20")

  // Parse and eval `1 ? (2 ? 3 : 4) : 5`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="3")

  // Parse and eval `20 / 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="5")

  // Parse and eval `17 % 5`
  let rest = skip_semi(rest)
  let (expr, _rest) = parse_constant_expr(rest)
  inspect(expr.eval(), content="2")
}
