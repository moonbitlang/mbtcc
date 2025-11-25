///|
using @lexer {type TokenKind}

///|
priv enum ConstantValue {
  Int(Int)
  UInt(UInt)
  Long(Int64)
  LongLong(Int64)
  ULong(UInt64)
  ULongLong(UInt64)
}

///|
fn ConstantValue::to_int64(self : ConstantValue) -> Int64 {
  match self {
    Int(v) => v.to_int64()
    UInt(v) => v.to_int64()
    Long(v) => v
    LongLong(v) => v
    ULong(v) => v.reinterpret_as_int64()
    ULongLong(v) => v.reinterpret_as_int64()
  }
}

///|
fn ConstantValue::negate(self : ConstantValue) -> ConstantValue {
  match self {
    Int(v) => Int(-v)
    UInt(v) => UInt(0U - v)
    Long(v) => Long(-v)
    LongLong(v) => LongLong(-v)
    ULong(v) => ULong(0UL - v)
    ULongLong(v) => ULongLong(0UL - v)
  }
}

///|
fn ConstantValue::bit_not(self : ConstantValue) -> ConstantValue {
  match self {
    Int(v) => Int(v.lnot())
    UInt(v) => UInt(v.lnot())
    Long(v) => Long(v.lnot())
    LongLong(v) => LongLong(v.lnot())
    ULong(v) => ULong(v.lnot())
    ULongLong(v) => ULongLong(v.lnot())
  }
}

///|
fn ConstantValue::logical_not(self : ConstantValue) -> ConstantValue {
  let is_zero = match self {
    Int(v) => v == 0
    UInt(v) => v == 0U
    Long(v) => v == 0L
    LongLong(v) => v == 0L
    ULong(v) => v == 0UL
    ULongLong(v) => v == 0UL
  }
  Int(if is_zero { 1 } else { 0 })
}

///|
// 类型提升：根据C语言的整数提升规则
// 如果任一操作数是无符号类型，则提升为无符号类型
fn promote_types(
  left : ConstantValue,
  right : ConstantValue,
) -> (UInt64, UInt64, Bool) {
  let left_is_unsigned = match left {
    UInt(_) | ULong(_) | ULongLong(_) => true
    _ => false
  }
  let right_is_unsigned = match right {
    UInt(_) | ULong(_) | ULongLong(_) => true
    _ => false
  }
  let is_unsigned = left_is_unsigned || right_is_unsigned
  let left_val = match left {
    Int(v) => v.to_int64().reinterpret_as_uint64()
    UInt(v) => v.to_uint64()
    Long(v) => v.reinterpret_as_uint64()
    LongLong(v) => v.reinterpret_as_uint64()
    ULong(v) => v
    ULongLong(v) => v
  }
  let right_val = match right {
    Int(v) => v.to_int64().reinterpret_as_uint64()
    UInt(v) => v.to_uint64()
    Long(v) => v.reinterpret_as_uint64()
    LongLong(v) => v.reinterpret_as_uint64()
    ULong(v) => v
    ULongLong(v) => v
  }
  (left_val, right_val, is_unsigned)
}

///|
fn ConstantValue::add(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left + right)
  } else {
    LongLong(left.reinterpret_as_int64() + right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::sub(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left - right)
  } else {
    LongLong(left.reinterpret_as_int64() - right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::mul(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left * right)
  } else {
    LongLong(left.reinterpret_as_int64() * right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::div(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left / right)
  } else {
    LongLong(left.reinterpret_as_int64() / right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::mod(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left % right)
  } else {
    LongLong(left.reinterpret_as_int64() % right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::shift_left(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let shift_amount = other.to_int64().to_int()
  match self {
    Int(v) => Int(v << shift_amount)
    UInt(v) => UInt(v << shift_amount)
    Long(v) => Long(v << shift_amount)
    LongLong(v) => LongLong(v << shift_amount)
    ULong(v) => ULong(v << shift_amount)
    ULongLong(v) => ULongLong(v << shift_amount)
  }
}

///|
fn ConstantValue::shift_right(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let shift_amount = other.to_int64().to_int()
  match self {
    Int(v) => Int(v >> shift_amount)
    UInt(v) => UInt(v >> shift_amount)
    Long(v) => Long(v >> shift_amount)
    LongLong(v) => LongLong(v >> shift_amount)
    ULong(v) => ULong(v >> shift_amount)
    ULongLong(v) => ULongLong(v >> shift_amount)
  }
}

///|
fn ConstantValue::lt(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  let result = if is_unsigned {
    left < right
  } else {
    left.reinterpret_as_int64() < right.reinterpret_as_int64()
  }
  Int(if result { 1 } else { 0 })
}

///|
fn ConstantValue::gt(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  let result = if is_unsigned {
    left > right
  } else {
    left.reinterpret_as_int64() > right.reinterpret_as_int64()
  }
  Int(if result { 1 } else { 0 })
}

///|
fn ConstantValue::le(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  let result = if is_unsigned {
    left <= right
  } else {
    left.reinterpret_as_int64() <= right.reinterpret_as_int64()
  }
  Int(if result { 1 } else { 0 })
}

///|
fn ConstantValue::ge(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  let result = if is_unsigned {
    left >= right
  } else {
    left.reinterpret_as_int64() >= right.reinterpret_as_int64()
  }
  Int(if result { 1 } else { 0 })
}

///|
fn ConstantValue::eq(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, _) = promote_types(self, other)
  Int(if left == right { 1 } else { 0 })
}

///|
fn ConstantValue::ne(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, _) = promote_types(self, other)
  Int(if left != right { 1 } else { 0 })
}

///|
fn ConstantValue::bit_and(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left & right)
  } else {
    LongLong(left.reinterpret_as_int64() & right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::bit_xor(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left ^ right)
  } else {
    LongLong(left.reinterpret_as_int64() ^ right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::bit_or(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let (left, right, is_unsigned) = promote_types(self, other)
  if is_unsigned {
    ULongLong(left | right)
  } else {
    LongLong(left.reinterpret_as_int64() | right.reinterpret_as_int64())
  }
}

///|
fn ConstantValue::logical_and(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let left_is_nonzero = match self {
    Int(v) => v != 0
    UInt(v) => v != 0U
    Long(v) => v != 0L
    LongLong(v) => v != 0L
    ULong(v) => v != 0UL
    ULongLong(v) => v != 0UL
  }
  let right_is_nonzero = match other {
    Int(v) => v != 0
    UInt(v) => v != 0U
    Long(v) => v != 0L
    LongLong(v) => v != 0L
    ULong(v) => v != 0UL
    ULongLong(v) => v != 0UL
  }
  Int(if left_is_nonzero && right_is_nonzero { 1 } else { 0 })
}

///|
fn ConstantValue::logical_or(
  self : ConstantValue,
  other : ConstantValue,
) -> ConstantValue {
  let left_is_nonzero = match self {
    Int(v) => v != 0
    UInt(v) => v != 0U
    Long(v) => v != 0L
    LongLong(v) => v != 0L
    ULong(v) => v != 0UL
    ULongLong(v) => v != 0UL
  }
  let right_is_nonzero = match other {
    Int(v) => v != 0
    UInt(v) => v != 0U
    Long(v) => v != 0L
    LongLong(v) => v != 0L
    ULong(v) => v != 0UL
    ULongLong(v) => v != 0UL
  }
  Int(if left_is_nonzero || right_is_nonzero { 1 } else { 0 })
}

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
    [tok, ..] => {
      println(tok)
      raise InvalidConstExprToken(
        tok,
        "Expected constant expression, got \{tok.kind}",
      )
    }
    [] =>
      raise InvalidConstExprToken(
        tokens[0],
        "Unexpected end of tokens in constant expression",
      )
  }
}

///|
fn PrimExpr::eval(self : PrimExpr) -> ConstantValue {
  match self {
    Int(value) => ConstantValue::Int(value)
    UInt(value) => ConstantValue::UInt(value)
    Long(value) => ConstantValue::Long(value)
    LongLong(value) => ConstantValue::LongLong(value)
    ULong(value) => ConstantValue::ULong(value)
    ULongLong(value) => ConstantValue::ULongLong(value)
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
fn UnaryExpr::eval(self : UnaryExpr) -> ConstantValue {
  match self {
    Prim(expr) => expr.eval()
    Negate(expr) => expr.eval().negate()
    BitNot(expr) => expr.eval().bit_not()
    LogicalNot(expr) => expr.eval().logical_not()
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
fn MultiExpr::eval(self : MultiExpr) -> ConstantValue {
  match self {
    Unary(expr) => expr.eval()
    Mul(left, right) => left.eval().mul(right.eval())
    Div(left, right) => left.eval().div(right.eval())
    Mod(left, right) => left.eval().mod(right.eval())
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
fn AddiExpr::eval(self : AddiExpr) -> ConstantValue {
  match self {
    Multi(expr) => expr.eval()
    Add(left, right) => left.eval().add(right.eval())
    Sub(left, right) => left.eval().sub(right.eval())
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
fn ShiftExpr::eval(self : ShiftExpr) -> ConstantValue {
  match self {
    Addi(expr) => expr.eval()
    ShlExpr(left, right) => left.eval().shift_left(right.eval())
    ShrExpr(left, right) => left.eval().shift_right(right.eval())
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
fn RelationalExpr::eval(self : RelationalExpr) -> ConstantValue {
  match self {
    Shift(expr) => expr.eval()
    LTExpr(left, right) => left.eval().lt(right.eval())
    GTExpr(left, right) => left.eval().gt(right.eval())
    LEExpr(left, right) => left.eval().le(right.eval())
    GEExpr(left, right) => left.eval().ge(right.eval())
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
fn EqualityExpr::eval(self : EqualityExpr) -> ConstantValue {
  match self {
    Relational(expr) => expr.eval()
    EQExpr(left, right) => left.eval().eq(right.eval())
    NEExpr(left, right) => left.eval().ne(right.eval())
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
fn AndExpr::eval(self : AndExpr) -> ConstantValue {
  match self {
    Equality(expr) => expr.eval()
    AndExpr(left, right) => left.eval().bit_and(right.eval())
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
fn ExclusiveOrExpr::eval(self : ExclusiveOrExpr) -> ConstantValue {
  match self {
    And(expr) => expr.eval()
    XorExpr(left, right) => left.eval().bit_xor(right.eval())
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
fn InclusiveOrExpr::eval(self : InclusiveOrExpr) -> ConstantValue {
  match self {
    ExclusiveOr(expr) => expr.eval()
    OrExpr(left, right) => left.eval().bit_or(right.eval())
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
fn LogicalAndExpr::eval(self : LogicalAndExpr) -> ConstantValue {
  match self {
    InclusiveOr(expr) => expr.eval()
    LogicalAndExpr(left, right) => left.eval().logical_and(right.eval())
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
fn LogicalOrExpr::eval(self : LogicalOrExpr) -> ConstantValue {
  match self {
    LogicalAnd(expr) => expr.eval()
    LogicalOrExpr(left, right) => left.eval().logical_or(right.eval())
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
fn ConstantExpr::eval(self : ConstantExpr) -> ConstantValue {
  match self {
    LogicalOr(expr) => expr.eval()
    ConstantExpr(cond, then_expr, else_expr) => {
      let cond_val = cond.eval()
      let is_nonzero = match cond_val {
        Int(v) => v != 0
        UInt(v) => v != 0U
        Long(v) => v != 0L
        LongLong(v) => v != 0L
        ULong(v) => v != 0UL
        ULongLong(v) => v != 0UL
      }
      if is_nonzero {
        then_expr.eval()
      } else {
        else_expr.eval()
      }
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
  inspect(expr.eval().to_int64(), content="42")

  // Parse and eval `-5`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="-5")

  // Parse and eval `~0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="-1")

  // Parse and eval `!0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="1")

  // Parse and eval `1 + 2`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="3")

  // Parse and eval `3 * 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="12")

  // Parse and eval `2 + 3 * 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="14")

  // Parse and eval `(2 + 3) * 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="20")

  // Parse and eval `5 > 3`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="1")

  // Parse and eval `5 == 5`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="1")

  // Parse and eval `1 && 0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="0")

  // Parse and eval `1 || 0`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="1")

  // Parse and eval `12 & 10`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="8")

  // Parse and eval `12 | 10`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="14")

  // Parse and eval `12 ^ 10`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="6")

  // Parse and eval `1 << 3`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="8")

  // Parse and eval `8 >> 2`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="2")

  // Parse and eval `1 ? 10 : 20`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="10")

  // Parse and eval `0 ? 10 : 20`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="20")

  // Parse and eval `1 ? (2 ? 3 : 4) : 5`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="3")

  // Parse and eval `20 / 4`
  let rest = skip_semi(rest)
  let (expr, rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="5")

  // Parse and eval `17 % 5`
  let rest = skip_semi(rest)
  let (expr, _rest) = parse_constant_expr(rest)
  inspect(expr.eval().to_int64(), content="2")
}
