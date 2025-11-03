
///|
///
/// Unary Expression
///
/// Unary expressions are expressions that involve a single operand and
/// perform operations such as incrementing, decrementing, negating,
/// taking the address of, or dereferencing a value.
///
/// ## Examples
///
/// ```c
/// ++x;               // Pre-increment
/// --y;               // Pre-decrement
/// &var;              // Address-of
/// *p;                // Dereference
/// -x;                // Negation
/// ~flag;             // Bitwise NOT
/// !condition;        // Logical NOT
/// sizeof(x);         // Sizeof expression
/// sizeof(int);       // Sizeof type
/// alignof(double);   // Alignof type
/// ```
///
pub struct UnaryExpr {
  kind: UnaryExprKind
  ctype: CType
  tokens: ArrayView[Token]
}

pub enum UnaryExprKind {
  PostfixExpr(PostfixExpr)
  PreInc(UnaryExpr)
  PreDec(UnaryExpr)
  AddrOf(UnaryExpr)
  Deref(UnaryExpr)
  Negate(UnaryExpr)
  BitNot(UnaryExpr)
  LogicalNot(UnaryExpr)
  SizeofExpr(UnaryExpr)
  SizeofType(CType)
  Alignof(CType)
}

pub fn Context::parse_unary_expr(
  self: Context,
  tokens: ArrayView[Token]
) -> (UnaryExpr, ArrayView[Token]) raise ParseError {
  let start_offset = tokens.start_offset()
  match tokens {
    [{ kind: Operator("++"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_inc_ok() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with '++' operator"
        raise ParseError(rest[0], msg)
      }
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: PreInc(inner_expr),
        ctype: inner_expr.ctype,
        tokens
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("--"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_dec_ok() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with '--' operator"
        raise ParseError(rest[0], msg)
      }
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: PreDec(inner_expr),
        ctype: inner_expr.ctype,
        tokens
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("&"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      let addr_ctype = inner_expr.ctype.ptr_to()
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: AddrOf(inner_expr),
        ctype: addr_ctype,
        tokens
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("*"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.dataKind is Ptr(deref_ctype) else {
        let msg = "Type '\{inner_expr.ctype}' cannot be dereferenced"
        raise ParseError(tokens[0], msg)
      }
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: Deref(inner_expr),
        ctype: deref_ctype,
        tokens
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("-"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_numeric() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be negated"
        raise ParseError(tokens[0], msg)
      }
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: Negate(inner_expr),
        ctype: inner_expr.ctype,
        tokens
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("~"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_integral() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with bitwise NOT operator"
        raise ParseError(tokens[0], msg)
      }
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: BitNot(inner_expr),
        ctype: inner_expr.ctype,
        tokens
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("!"), ..}, ..rest] as tokens => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_integral() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with logical NOT operator"
        raise ParseError(tokens[0], msg)
      }
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: LogicalNot(inner_expr),
        ctype: inner_expr.ctype,
        tokens
      }
      (unary_expr, rest)
    }
    //[{ kind: Keyword(Sizeof), ..}, 
    // { kind: Bracket('('), ..},
    // { kind: Keyword(_), ..},
    // .. rest
    //] => {}
    //[{ kind: Keyword(Sizeof), ..}, 
    // { kind: Bracket('('), ..},
    // { kind: Identifier(name), ..},
    // .. rest
    //] if self.is_type_name(name) => {}
    _ => {
      let (postfix_expr, rest) = self.parse_postfix_expr(tokens)
      let tokens = tokens[0:(rest.start_offset() - start_offset)]
      let unary_expr = UnaryExpr::{
        kind: PostfixExpr(postfix_expr),
        ctype: postfix_expr.ctype,
        tokens
      }
      (unary_expr, rest)
    }
  }
}
