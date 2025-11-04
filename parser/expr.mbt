
pub struct CastExpr {
  unary_expr: UnaryExpr
  // if no `(typename)` cast
  // set `cst_to` is same as `unary_expr.ctype`
  cast_to: CType
  tokens: ArrayView[Token]
}

pub impl Eq for CastExpr with equal(self, other) {
  self.unary_expr == other.unary_expr &&
  self.cast_to == other.cast_to
}

pub impl Show for CastExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///
/// if cast_to == unary_expr.ctype, just print unary_expr
/// if not, print like:
///
/// cast expr: cast to \{cast_to}
/// `\{unary_expr}
pub fn CastExpr::to_string(self: Self, color~: Bool = true, indent~ : Int = 0) -> String {
  if self.cast_to == self.unary_expr.ctype {
    return self.unary_expr.to_string(color~, indent~)
  }
  let prefix = if color {
    @color.taint("cast expr: cast to \{self.cast_to}", Magenta)
  } else {
    "cast expr: cast to \{self.cast_to}"
  }
  let s = self.unary_expr.to_string(color~, indent~)
  let s = "\{prefix}\n" + "`\{s}"
  " ".repeat(indent) + s
}

pub fn Context::parse_cast_expr(
  self: Self,
  tokens: ArrayView[Token]
) -> (CastExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  match tokens {
    [{ kind: Bracket('('), ..}, tok, ..] if
    self.is_keyword_or_type_name(tok) => {
      //TODO: Skip for we didn't implement type_name parser yet
      // Call parse_cast_expr recursively, so it will return
      ...
    }
    _ => ()
  }
  let (unary_expr, rest) = self.parse_unary_expr(tokens)
  let tokens = init_toks[0:(rest.start_offset() - start_offset)]
  let cast_to = unary_expr.ctype
  let cast_expr = CastExpr::{ unary_expr, cast_to, tokens }
  (cast_expr, rest)
}


pub struct MultiExpr {
  left: CastExpr
  op: MultiOp
  right: CastExpr
  tokens: ArrayView[Token]
}

pub(all) enum MultiOp {
  Mul
  Div
  Mod
}

pub struct AddiExpr {
  left: MultiExpr
  op: AddiOp
  right: MultiExpr
  tokens: ArrayView[Token]
}

pub(all) enum AddiOp {
  Add
  Sub
}

pub struct ShiftExpr {
  left: AddiExpr
  op: ShiftOp
  right: AddiExpr
  tokens: ArrayView[Token]
}

pub(all) enum ShiftOp {
  Shl
  Shr
}

pub struct RelationalExpr {
  left: ShiftExpr
  op: RelationOp
  right: ShiftExpr
  tokens: ArrayView[Token]
}

pub(all) enum RelationOp {
  Lt
  Gt
  Le
  Ge
}

pub struct EqualityExpr {
  left: RelationalExpr
  op: EqualityOp
  right: RelationalExpr
  tokens: ArrayView[Token]
}

pub(all) enum EqualityOp {
  Eq
  Ne
}

pub struct AndExpr {
  left: EqualityExpr
  right: EqualityExpr
  tokens: ArrayView[Token]
}

pub struct ExclusiveOrExpr {
  left: AndExpr
  right: AndExpr
  tokens: ArrayView[Token]
}

pub struct InclusiveOrExpr {
  left: ExclusiveOrExpr
  right: ExclusiveOrExpr
  tokens: ArrayView[Token]
}

pub struct LogicalAndExpr {
  left: InclusiveOrExpr
  right: InclusiveOrExpr
  tokens: ArrayView[Token]
}

pub struct LogicalOrExpr {
  left: LogicalAndExpr
  right: LogicalAndExpr
  tokens: ArrayView[Token]
}

pub struct ConditionalExpr {
  cond: LogicalOrExpr
  then_expr: LogicalOrExpr
  else_expr: LogicalOrExpr
  tokens: ArrayView[Token]
}

// Convert From ConditionalExpr, but check all
// operands are constant expressions
pub struct ConstantExpr {
  cond: LogicalOrExpr
  then_expr: LogicalOrExpr
  else_expr: LogicalOrExpr
  tokens: ArrayView[Token]
}

pub struct AssignExpr {
  kind: AssignExprKind
  ctype: CType
  tokens: ArrayView[Token]
}

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
}

pub struct Expr {
  assign_exprs: Array[AssignExpr]
  tokens: ArrayView[Token]
}
