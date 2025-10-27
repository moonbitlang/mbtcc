

pub struct PrimExpr {
  kind: PrimExprKind
  tokens: ArrayView[Token]
}

pub enum PrimExprKind {
  Ident(String)
  Char(Char)
  Int(Int)
  UInt(UInt)
  Long(Int64)
  ULong(UInt64)
  Float(Float)
  Double(Double)
  Strings(Array[String])
  // Paren(Expr) // TODO
}

pub fn Context::parse_prim_expr(
  tokens: ArrayView[Token]
) -> (PrimExpr, ArrayView[Token]) raise ParseError {
  let start_offset = tokens.start_offset()
  let (prim_expr_kind, rest_toks) = match tokens {
    [{ kind: Int(v), ..}, ..rest] => {
      (Int(v), rest)
    }
    [{ kind: Long(v), ..}, ..rest] => {
      (Long(v), rest)
    }
    [{ kind: UInt(v), ..}, ..rest] => {
      (UInt(v), rest)
    }
    [{ kind: ULong(v), ..}, ..rest] => {
      (ULong(v), rest)
    }
    [{ kind: Float(v), ..}, ..rest] => {
      (Float(v), rest)
    }
    [{ kind: Double(v), ..}, ..rest] => {
      (Double(v), rest)
    }
    [{ kind: Char(c), ..}, ..rest] => {
      (Char(c), rest)
    }
    [{ kind: Identifier(name), ..}, ..rest] => {
      (Ident(name), rest)
    }
    [{kind: String(_), ..}, ..] as tokens => {
      let strs : Array[String] = Array::new()
      let rest_tokens = loop tokens {
        [{kind: String(s), ..}, ..rest] => {
          strs.push(s)
          continue rest
        }
        rest => break rest
      }
      (Strings(strs), rest_tokens)
    }
    tokens => raise ParseError(tokens[0], "Expected a primary expression")
  }
  let end_offset = rest_toks.start_offset()
  let offset_range = end_offset - start_offset
  let tok_view = tokens[0:offset_range]
  let prim_expr = PrimExpr::{
    kind: prim_expr_kind,
    tokens: tok_view
  }
  (prim_expr, rest_toks)
}

test "PrimExpr Parse Test" {

}
