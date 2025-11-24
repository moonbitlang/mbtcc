///|
enum PrimExpr {
  Int(Int)
  UInt(UInt)
  Long(Int64)
  LongLong(Int64)
  ULong(UInt64)
  ULongLong(UInt64)
}

///|
fn parse_prim_expr(tokens : ArrayView[Token]) -> PrimExpr raise PreprecessError {
  raise Unimplemented("parse_prim_expr is not implemented")
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
  }
}

///|
enum UnaryExpr {
  Negate(PrimExpr)
  BitNot(PrimExpr)
  LogicalNot(PrimExpr)
}

///|
fn parse_unary_expr(
  tokens : ArrayView[Token],
) -> UnaryExpr raise PreprecessError {
  raise Unimplemented("parse_unary_expr is not implemented")
}

///|
fn UnaryExpr::eval(self : UnaryExpr) -> Int64 {
  match self {
    Negate(expr) => -expr.eval()
    BitNot(expr) => expr.eval().lnot()
    LogicalNot(expr) => (expr.eval() == 0).to_int64()
  }
}

///|
enum MultiExpr {
  Unary(UnaryExpr)
  Mul(MultiExpr, UnaryExpr)
  Div(MultiExpr, UnaryExpr)
  Mod(MultiExpr, UnaryExpr)
}

///|
fn parse_multi_expr(
  tokens : ArrayView[Token],
) -> MultiExpr raise PreprecessError {
  raise Unimplemented("parse_multi_expr is not implemented")
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
enum AddiExpr {
  Multi(MultiExpr)
  Add(AddiExpr, MultiExpr)
  Sub(AddiExpr, MultiExpr)
}

///|
fn parse_addi_expr(tokens : ArrayView[Token]) -> AddiExpr raise PreprecessError {
  raise Unimplemented("parse_addi_expr is not implemented")
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
enum ShiftExpr {
  Addi(AddiExpr)
  ShlExpr(ShiftExpr, AddiExpr)
  ShrExpr(ShiftExpr, AddiExpr)
}

///|
fn parse_shift_expr(
  tokens : ArrayView[Token],
) -> ShiftExpr raise PreprecessError {
  raise Unimplemented("parse_shift_expr is not implemented")
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
enum RelationalExpr {
  Shift(ShiftExpr)
  LTExpr(RelationalExpr, ShiftExpr)
  GTExpr(RelationalExpr, ShiftExpr)
  LEExpr(RelationalExpr, ShiftExpr)
  GEExpr(RelationalExpr, ShiftExpr)
}

///|
fn parse_relational_expr(
  tokens : ArrayView[Token],
) -> RelationalExpr raise PreprecessError {
  raise Unimplemented("parse_relational_expr is not implemented")
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
enum EqualityExpr {
  Relational(RelationalExpr)
  EQExpr(EqualityExpr, RelationalExpr)
  NEExpr(EqualityExpr, RelationalExpr)
}

///|
fn parse_equality_expr(
  tokens : ArrayView[Token],
) -> EqualityExpr raise PreprecessError {
  raise Unimplemented("parse_equality_expr is not implemented")
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
enum AndExpr {
  Equality(EqualityExpr)
  AndExpr(AndExpr, EqualityExpr)
}

///|
fn parse_and_expr(tokens : ArrayView[Token]) -> AndExpr raise PreprecessError {
  raise Unimplemented("parse_and_expr is not implemented")
}

///|
fn AndExpr::eval(self : AndExpr) -> Int64 {
  match self {
    Equality(expr) => expr.eval()
    AndExpr(left, right) => left.eval() & right.eval()
  }
}

///|
enum ExclusiveOrExpr {
  And(AndExpr)
  XorExpr(ExclusiveOrExpr, AndExpr)
}

///|
fn parse_exclusive_or_expr(
  tokens : ArrayView[Token],
) -> ExclusiveOrExpr raise PreprecessError {
  raise Unimplemented("parse_exclusive_or_expr is not implemented")
}

///|
fn ExclusiveOrExpr::eval(self : ExclusiveOrExpr) -> Int64 {
  match self {
    And(expr) => expr.eval()
    XorExpr(left, right) => left.eval() ^ right.eval()
  }
}

///|
enum InclusiveOrExpr {
  ExclusiveOr(ExclusiveOrExpr)
  OrExpr(InclusiveOrExpr, ExclusiveOrExpr)
}

///|
fn parse_inclusive_or_expr(
  tokens : ArrayView[Token],
) -> InclusiveOrExpr raise PreprecessError {
  raise Unimplemented("parse_inclusive_or_expr is not implemented")
}

///|
fn InclusiveOrExpr::eval(self : InclusiveOrExpr) -> Int64 {
  match self {
    ExclusiveOr(expr) => expr.eval()
    OrExpr(left, right) => left.eval() | right.eval()
  }
}

///|
enum LogicalAndExpr {
  InclusiveOr(InclusiveOrExpr)
  LogicalAndExpr(LogicalAndExpr, InclusiveOrExpr)
}

///|
fn parse_logical_and_expr(
  tokens : ArrayView[Token],
) -> LogicalAndExpr raise PreprecessError {
  raise Unimplemented("parse_logical_and_expr is not implemented")
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
enum LogicalOrExpr {
  LogicalAnd(LogicalAndExpr)
  LogicalOrExpr(LogicalOrExpr, LogicalAndExpr)
}

///|
fn parse_logical_or_expr(
  tokens : ArrayView[Token],
) -> LogicalOrExpr raise PreprecessError {
  raise Unimplemented("parse_logical_or_expr is not implemented")
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
enum ConstantExpr {
  LogicalOr(LogicalOrExpr)
  ConstantExpr(LogicalOrExpr, ConstantExpr, ConstantExpr)
}

///|
fn parse_constant_expr(
  tokens : ArrayView[Token],
) -> ConstantExpr raise PreprecessError {
  raise Unimplemented("parse_constant_expr is not implemented")
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
