// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub suberror ParseError (Int, String) derive(Show, Eq)

//primaryExpression
//    : Identifier
//    | Constant
//    | StringLiteral+
//    | '(' expression ')'
//    | genericSelection
//    | '__extension__'? '(' compoundStatement ')' // Blocks (GCC extension)
//    | '__builtin_va_arg' '(' unaryExpression ',' typeName ')'
//    | '__builtin_offsetof' '(' typeName ',' unaryExpression ')'
//    ;

///|
pub enum PrimExpr {
  Identifier(String)
  Constant(Constant)
  StringLiteral(String)
  ParenExpr(Expr)
  BuiltinOffsetof(TypeName, UnaryExpr)
  //GenericSelection
  GCCExtBlock(CompoundStatement)
} derive(Show, Eq)

///|
fn PrimExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (PrimExpr, ArrayView[Token]) raise {
  match toks {
    [Identifier(name), .. rest_toks] if !ctx.typedefs.contains(name) =>
      (PrimExpr::Identifier(name), rest_toks)
    [Identifier(name), ..] => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Identifier \{name} is a type, cannot be used as a primary expression",
        ),
      )
    }
    [Constant(constant), .. rest_toks] =>
      (PrimExpr::Constant(constant), rest_toks)
    [StringLiteral(lit), .. rest_toks] => {
      let mut str = lit
      let rest_toks = loop rest_toks {
        [StringLiteral(next_lit), .. next_rest] => {
          str += next_lit
          continue next_rest
        }
        rest_toks => break rest_toks
      }
      (PrimExpr::StringLiteral(str), rest_toks)
    }
    [LParen, LBrace, ..] as toks => {
      let (comp_stmt, rest) = CompoundStatement::parse(toks[1:], ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected ')' to close block statement"),
        )
      }
      (PrimExpr::GCCExtBlock(comp_stmt), rest_toks)
    }
    [LParen, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing parenthesis after expression"),
        )
      }
      (PrimExpr::ParenExpr(expr), rest_toks)
    }
    [BuiltinOffsetof, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [Comma, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected ',' after type name in __builtin_offsetof",
          ),
        )
      }
      let (unary_expr, rest_toks) = UnaryExpr::parse(rest_toks, ctx)
      guard rest_toks is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest_toks.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after unary expression in __builtin_offsetof",
          ),
        )
      }
      (PrimExpr::BuiltinOffsetof(type_name, unary_expr), rest_toks)
    }
    [BuiltinOffsetof, .. rest_toks] => {
      let idx = ctx.alltoks.length() - rest_toks.length()
      raise ParseError(
        (idx, "Parse Error: Expected '(' after __builtin_offsetof"),
      )
    }
    curr_toks => {
      let idx = ctx.alltoks.length() - curr_toks.length()
      raise ParseError(
        (
          idx,
          "PrimExpr Parse Error: Expected Identifier, Constant, StringLiteral, or '(' expression ')', but found \{curr_toks[0]}",
        ),
      )
    }
  }
}

///|
test "PrimExpr Parsing Test" {
  let code_expect_rest : Map[String, (PrimExpr, ArrayView[Token])] = {
    "abc + ": (PrimExpr::Identifier("abc"), [Plus, EOF]),
    "123 - ": (PrimExpr::Constant(Constant::Int(123)), [Minus, EOF]),
    "\"hello \" \"world\" ": (PrimExpr::StringLiteral("hello world"), [EOF]),
  }
  for code, expect_rest in code_expect_rest {
    let (expect_prim, expect_rest_toks) = expect_rest
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (prim, rest_toks) = PrimExpr::parse(toks, ctx)
    assert_eq(prim, expect_prim)
    assert_eq(rest_toks, expect_rest_toks)
  }
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "(abc + 123) - 456": [Minus, Constant(Constant::Int(456)), EOF],
    "(a + b) * c": [Star, Identifier("c"), EOF],
    "({int x = 1, y = 2; x + y;})": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = PrimExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "PrimExpr Parsing Negative Test" {
  let code = "MyInt + 1"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? PrimExpr::parse(toks, ctx)) is Ok(_))
  ctx.typedefs.set("MyInt", 1)
  assert_true((try? PrimExpr::parse(toks, ctx)) is Err(ParseError((0, _))))
  let code = "(a + 1 ;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? PrimExpr::parse(toks, ctx)) is Err(ParseError((4, _))))
  let code = " ++ 3 "
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? PrimExpr::parse(toks, ctx)) is Err(ParseError((0, _))))
}

//postfixExpression
//    : (primaryExpression | '__extension__'? '(' typeName ')' '{' initializerList ','? '}') (
//        '[' expression ']'
//        | '(' argumentExpressionList? ')'
//        | ('.' | '->') Identifier
//        | '++'
//        | '--'
//    )*
//    ;

///|
pub struct PostFixExpr {
  head : Either[PrimExpr, (TypeName, InitializerList)]
  suffixes : Array[PostFixSuffix]
} derive(Show, Eq)

///|
fn PostFixExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (PostFixExpr, ArrayView[Token]) raise {
  let (head, rest_toks) = if toks is [LParen, .. rtoks] &&
    (try? TypeName::parse(rtoks, ctx)) is Ok((ty_name, rtoks)) {
    guard rtoks is [RParen, LBrace, ..] else {
      let idx = ctx.alltoks.length() - rtoks.length()
      raise ParseError(
        (
          idx, "Parse Error: Expected ')' and '{' after type name in compound literal",
        ),
      )
    }
    let (init_list, rest_toks) = InitializerList::parse(rtoks[1:], ctx)
    (Either::Right((ty_name, init_list)), rest_toks)
  } else {
    let (prim, rest) = PrimExpr::parse(toks, ctx)
    (Either::Left(prim), rest)
  }
  let (suffixes, rest_toks) = PostFixSuffix::parse(rest_toks, ctx)
  let post_fix_expr = PostFixExpr::{ head, suffixes }
  (post_fix_expr, rest_toks)
}

///|
pub enum PostFixSuffix {
  Indexing(Expr)
  Call(Array[AssignExpr])
  DotAccess(String)
  ArrowAccess(String)
  PlusPlus
  MinusMinus
} derive(Show, Eq)

///|
fn PostFixSuffix::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Array[PostFixSuffix], ArrayView[Token]) raise {
  let suffixes : Array[PostFixSuffix] = Array::new()
  let rest_toks = loop toks {
    [PlusPlus, .. rest_toks] => {
      suffixes.push(PostFixSuffix::PlusPlus)
      continue rest_toks
    }
    [MinusMinus, .. rest_toks] => {
      suffixes.push(PostFixSuffix::MinusMinus)
      continue rest_toks
    }
    [Dot, Identifier(name), .. rest_toks] => {
      suffixes.push(PostFixSuffix::DotAccess(name))
      continue rest_toks
    }
    [Dot, .. rest] => {
      let idx = ctx.alltoks.length() - rest.length()
      raise ParseError(
        (
          idx, "Parse Error: Expected identifier after '.' in postfix expression",
        ),
      )
    }
    [Arrow, Identifier(name), .. rest_toks] => {
      suffixes.push(PostFixSuffix::ArrowAccess(name))
      continue rest_toks
    }
    [Arrow, .. rest] => {
      let idx = ctx.alltoks.length() - rest.length()
      raise ParseError(
        (
          idx, "Parse Error: Expected identifier after '->' in postfix expression",
        ),
      )
    }
    [LBracket, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing bracket after expression"),
        )
      }
      suffixes.push(PostFixSuffix::Indexing(expr))
      continue rest_toks
    }
    [LParen, RParen, .. rest_toks] => {
      suffixes.push(PostFixSuffix::Call(Array::new())) // Empty argument list
      continue rest_toks
    }
    [LParen, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after argument expression list",
          ),
        )
      }
      let args = expr.exprs
      suffixes.push(PostFixSuffix::Call(args))
      continue rest_toks
    }
    toks => break toks // No more postfix suffixes
  }
  (suffixes, rest_toks)
}

///|
test "PostfixExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "abc++ + b": [Plus, Identifier("b"), EOF],
    "abc-- + b": [Plus, Identifier("b"), EOF],
    "point.x * 9": [Star, Constant(Constant::Int(9)), EOF],
    "p->x / 3": [Slash, Constant(Constant::Int(3)), EOF],
    "fact(42) * 7": [Star, Constant(Constant::Int(7)), EOF],
    "printf(\"The number is %d\", 42);": [Semi, EOF],
    "mat[0][i]++;": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = PostFixExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "PostifxExpr Parsing Negative Test" {
  let code = "arr[index;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? PostFixExpr::parse(toks, ctx)) is Err(ParseError((3, _))))
  let code = "func(arg;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? PostFixExpr::parse(toks, ctx)) is Err(ParseError((3, _))))

  // 测试箭头后面缺少标识符
  let code = "ptr->123"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? PostFixExpr::parse(toks, ctx)) is Err(ParseError((2, _)))) // 应该成功，只是没有后缀
}

//unaryExpression
//    : ('++' | '--' | 'sizeof')* (
//        postfixExpression
//        | unaryOperator castExpression
//        | ('sizeof' | '_Alignof') '(' typeName ')'
//        | '&&' Identifier // GCC extension address of label
//    )
//    ;

///|
pub struct UnaryExpr {
  prefix : Array[UnaryPrefix]
  body : UnaryExprBody
} derive(Show, Eq)

///|
fn UnaryExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (UnaryExpr, ArrayView[Token]) raise {
  let (prefixes, rest_toks) = UnaryPrefix::parse(toks, ctx)
  let (body, rest_toks) = UnaryExprBody::parse(rest_toks, ctx)
  let unary_expr = UnaryExpr::{ prefix: prefixes, body }
  (unary_expr, rest_toks)
}

///|
pub enum UnaryPrefix {
  PlusPlus
  MinusMinus
  Sizeof
} derive(Show, Eq)

///|
fn UnaryPrefix::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Array[UnaryPrefix], ArrayView[Token]) {
  let prefixes : Array[UnaryPrefix] = Array::new()
  let rest_toks = loop toks {
    [PlusPlus, .. rest_toks] => {
      prefixes.push(UnaryPrefix::PlusPlus)
      continue rest_toks
    }
    [MinusMinus, .. rest_toks] => {
      prefixes.push(UnaryPrefix::MinusMinus)
      continue rest_toks
    }
    // if `sizeof(` check it if it is `sizeof(typename)`, if so, need to break
    [Sizeof, LParen, .. rest_toks] as toks =>
      //match (try? TypeName::parse(rest_toks, ctx)) {
      //  Err(_) => {
      //    prefixes.push(UnaryPrefix::Sizeof)
      //    continue toks[1:]
      //  }
      //  Ok(_) => break toks
      //}
      try TypeName::parse(rest_toks, ctx) catch {
        _ => {
          prefixes.push(UnaryPrefix::Sizeof)
          continue toks[1:]
        }
      } noraise {
        _ => break toks
      }
    [Sizeof, .. rest_toks] => {
      prefixes.push(UnaryPrefix::Sizeof)
      continue rest_toks
    }
    toks => break toks // No more unary prefixes
  }
  (prefixes, rest_toks)
}

///|
pub enum UnaryOperator {
  AddressOf // &
  Dereference // *
  Positive // +
  Negative // -
  LogicalNot // !
  BitwiseNot // ~
} derive(Show, Eq)

///|
pub enum UnaryExprBody {
  PostFix(PostFixExpr)
  UnaryOp(UnaryOperator, CastExpr)
  SizeofTypeName(TypeName)
  AlignOfTypeName(TypeName)
} derive(Show, Eq)

///|
fn UnaryExprBody::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (UnaryExprBody, ArrayView[Token]) raise {
  match toks {
    [And | Star | Plus | Minus | Not | Tilde as sym, .. rest_toks] => {
      let (cast_expr, rest_toks) = CastExpr::parse(rest_toks, ctx)
      let unary_op = match sym {
        And => AddressOf
        Star => Dereference
        Plus => Positive
        Minus => Negative
        Not => LogicalNot
        _ => BitwiseNot // Tilde
      }
      (UnaryExprBody::UnaryOp(unary_op, cast_expr), rest_toks)
    }
    [Sizeof, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx,
            "Parse Error: Expected closing parenthesis after type name in sizeof, while get \{rest[0]}",
          ),
        )
      }
      (UnaryExprBody::SizeofTypeName(type_name), rest_toks)
    }
    [Alignof, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after type name in _Alignof",
          ),
        )
      }
      (UnaryExprBody::AlignOfTypeName(type_name), rest_toks)
    }
    toks => {
      let (post_fix_expr, rest_toks) = PostFixExpr::parse(toks, ctx)
      (UnaryExprBody::PostFix(post_fix_expr), rest_toks)
    }
  }
}

///|
test "UnaryExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "++abc + b": [Plus, Identifier("b"), EOF],
    "--abc + b": [Plus, Identifier("b"), EOF],
    "sizeof(int) + 1": [Plus, Constant(Constant::Int(1)), EOF],
    "sizeof(42) + 1": [Plus, Constant(Constant::Int(1)), EOF],
    "sizeof 42 + 1": [Plus, Constant(Constant::Int(1)), EOF],
    "_Alignof(int) + 2": [Plus, Constant(Constant::Int(2)), EOF],
    "&abc + b": [Plus, Identifier("b"), EOF],
    "*abc + b": [Plus, Identifier("b"), EOF],
    "+abc + b": [Plus, Identifier("b"), EOF],
    "-abc + b": [Plus, Identifier("b"), EOF],
    "!abc + b": [Plus, Identifier("b"), EOF],
    "~abc + b": [Plus, Identifier("b"), EOF],
    "++mat[i][j];": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = UnaryExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "UnaryExpr Parsing Negative Test" {
  let code = "sizeof(int ;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? UnaryExpr::parse(toks, ctx)) is Err(ParseError((3, _))))
  let code = "_Alignof(double; "
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? UnaryExpr::parse(toks, ctx)) is Err(ParseError((3, _))))
}

//castExpression
//    : '__extension__'? '(' typeName ')' castExpression
//    | unaryExpression
//    | DigitSequence // for
//    ;
//type CastExpr (Array[TypeName], UnaryExpr) derive(Show, Eq)

///|
pub enum CastExpr {
  UnaryExpr(UnaryExpr)
  Cast(TypeName, CastExpr)
} derive(Show, Eq)

///|
fn CastExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (CastExpr, ArrayView[Token]) raise {
  if toks is [LParen, .. rtoks] &&
    (try? TypeName::parse(rtoks, ctx)) is Ok((_, rtoks)) &&
    rtoks is [RParen, LBrace, ..] {
    // This is a compound literal, not a cast expression
    let (unary_expr, rest_toks) = UnaryExpr::parse(toks, ctx)
    return (CastExpr::UnaryExpr(unary_expr), rest_toks)
  }
  if toks is [LParen, .. rtoks] &&
    (try? TypeName::parse(rtoks, ctx)) is Ok((ty, rtoks)) &&
    rtoks is [RParen, .. rtoks] {
    // This is a cast expression
    let (cast_expr, rest_toks) = CastExpr::parse(rtoks, ctx)
    return (CastExpr::Cast(ty, cast_expr), rest_toks)
  }

  // Otherwise, it is a unary expression
  let (unary_expr, rest_toks) = UnaryExpr::parse(toks, ctx)
  (CastExpr::UnaryExpr(unary_expr), rest_toks)
}

///|
test "CastExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "(int)abc + b": [Plus, Identifier("b"), EOF],
    "(int)(float)abc + b": [Plus, Identifier("b"), EOF],
    "(int)123 + b": [Plus, Identifier("b"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = CastExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "CastExpr Parsing Negative Test" {
  let code = "(int + 1"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? CastExpr::parse(toks, ctx)) is Err(ParseError((2, _))))
}

//multiplicativeExpression
//    : castExpression (('*' | '/' | '%') castExpression)*
//    ;

///|
pub struct MultExpr {
  exprs : Array[CastExpr]
  ops : Array[MultOp]
} derive(Show, Eq)

///|
pub enum MultOp {
  Mult // *
  Div // /
  Mod // %
} derive(Show, Eq)

///|
fn MultExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (MultExpr, ArrayView[Token]) raise {
  let exprs : Array[CastExpr] = Array::new()
  let ops : Array[MultOp] = Array::new()
  let (first_expr, rest_toks) = CastExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Star, .. rest_toks] => {
      ops.push(MultOp::Mult)
      let (next_expr, rest) = CastExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [Slash, .. rest_toks] => {
      ops.push(MultOp::Div)
      let (next_expr, rest) = CastExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [Mod, .. rest_toks] => {
      ops.push(MultOp::Mod)
      let (next_expr, rest) = CastExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let mult_expr = MultExpr::{ exprs, ops }
  (mult_expr, rest_toks)
}

///|
test "MultExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "abc * b + bbcc": [Plus, Identifier("bbcc"), EOF],
    "abc / b + a123": [Plus, Identifier("a123"), EOF],
    "abc % b - u89": [Minus, Identifier("u89"), EOF],
    "123 * 456 + 789": [Plus, Constant(Constant::Int(789)), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = MultExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//additiveExpression
//    : multiplicativeExpression (('+' | '-') multiplicativeExpression)*
//    ;

///|
pub struct AddSubExpr {
  exprs : Array[MultExpr]
  ops : Array[AddSubOp]
} derive(Show, Eq)

///|
pub enum AddSubOp {
  Add // +
  Sub // -
} derive(Show, Eq)

///|
fn AddSubExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (AddSubExpr, ArrayView[Token]) raise {
  let exprs : Array[MultExpr] = Array::new()
  let ops : Array[AddSubOp] = Array::new()
  let (first_expr, rest_toks) = MultExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Plus, .. rest_toks] => {
      ops.push(AddSubOp::Add)
      let (next_expr, rest) = MultExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [Minus, .. rest_toks] => {
      ops.push(AddSubOp::Sub)
      let (next_expr, rest) = MultExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let add_sub_expr = AddSubExpr::{ exprs, ops }
  (add_sub_expr, rest_toks)
}

///|
test "AddSubExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "abc + b - c > 78": [GT, Constant(Constant::Int(78)), EOF],
    "abc - b + d <= 96": [LE, Constant(Constant::Int(96)), EOF],
    "123 + 456 - 789 == 12345": [EQ, Constant(Constant::Int(12345)), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AddSubExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//shiftExpression
//    : additiveExpression (('<<' | '>>') additiveExpression)*
//    ;

///|
pub struct ShiftExpr {
  exprs : Array[AddSubExpr]
  ops : Array[ShiftOp]
} derive(Show, Eq)

///|
pub enum ShiftOp {
  Shl // <<
  Shr // >>
} derive(Show, Eq)

///|
fn ShiftExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ShiftExpr, ArrayView[Token]) raise {
  let exprs : Array[AddSubExpr] = Array::new()
  let ops : Array[ShiftOp] = Array::new()
  let (first_expr, rest_toks) = AddSubExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Shl, .. rest_toks] => {
      ops.push(ShiftOp::Shl)
      let (next_expr, rest) = AddSubExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [Shr, .. rest_toks] => {
      ops.push(ShiftOp::Shr)
      let (next_expr, rest) = AddSubExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let shift_expr = ShiftExpr::{ exprs, ops }
  (shift_expr, rest_toks)
}

///|
test "ShiftExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a << 1 > 345 ": [GT, Constant(Constant::Int(345)), EOF],
    "b >> 2 < 456": [LT, Constant(Constant::Int(456)), EOF],
    "c << 3 == 789": [EQ, Constant(Constant::Int(789)), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ShiftExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//relationalExpression
//    : shiftExpression (('<' | '>' | '<=' | '>=') shiftExpression)*
//    ;

///|
pub struct RelationalExpr {
  exprs : Array[ShiftExpr]
  ops : Array[RelationalOp]
} derive(Show, Eq)

///|
pub enum RelationalOp {
  LT // <
  GT // >
  LE // <=
  GE // >=
} derive(Show, Eq)

///|
fn RelationalExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (RelationalExpr, ArrayView[Token]) raise {
  let exprs : Array[ShiftExpr] = Array::new()
  let ops : Array[RelationalOp] = Array::new()
  let (first_expr, rest_toks) = ShiftExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [LT, .. rest_toks] => {
      ops.push(RelationalOp::LT)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [GT, .. rest_toks] => {
      ops.push(RelationalOp::GT)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [LE, .. rest_toks] => {
      ops.push(RelationalOp::LE)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [GE, .. rest_toks] => {
      ops.push(RelationalOp::GE)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let relational_expr = RelationalExpr::{ exprs, ops }
  (relational_expr, rest_toks)
}

///|
test "RelationalExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a < b + c && True": [DoubleAnd, Identifier("True"), EOF],
    "d > e - f || False": [DoubleOr, Identifier("False"), EOF],
    "g <= h * i && cond": [DoubleAnd, Identifier("cond"), EOF],
    "j >= k / l || cond": [DoubleOr, Identifier("cond"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = RelationalExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//equalityExpression
//    : relationalExpression (('==' | '!=') relationalExpression)*
//    ;

///|
pub struct EqualityExpr {
  exprs : Array[RelationalExpr]
  ops : Array[EqualityOp]
} derive(Show, Eq)

///|
pub enum EqualityOp {
  EQ // ==
  NE // !=
} derive(Show, Eq)

///|
fn EqualityExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (EqualityExpr, ArrayView[Token]) raise {
  let exprs : Array[RelationalExpr] = Array::new()
  let ops : Array[EqualityOp] = Array::new()
  let (first_expr, rest_toks) = RelationalExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [EQ, .. rest_toks] => {
      ops.push(EqualityOp::EQ)
      let (next_expr, rest) = RelationalExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    [NE, .. rest_toks] => {
      ops.push(EqualityOp::NE)
      let (next_expr, rest) = RelationalExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let equality_expr = EqualityExpr::{ exprs, ops }
  (equality_expr, rest_toks)
}

///|
test "EqualityExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a == b + c || True": [DoubleOr, Identifier("True"), EOF],
    "d != e - f && False": [DoubleAnd, Identifier("False"), EOF],
    "g == h * i || cond": [DoubleOr, Identifier("cond"), EOF],
    "j != k / l && cond": [DoubleAnd, Identifier("cond"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = EqualityExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//andExpression
//    : equalityExpression ('&' equalityExpression)*
//    ;

///|
pub struct AndExpr {
  exprs : Array[EqualityExpr]
} derive(Show, Eq)

///|
fn AndExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (AndExpr, ArrayView[Token]) raise {
  let exprs : Array[EqualityExpr] = Array::new()
  let (first_expr, rest_toks) = EqualityExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [And, .. rest_toks] => {
      let (next_expr, rest) = EqualityExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let and_expr = AndExpr::{ exprs, }
  (and_expr, rest_toks)
}

///|
test "AndExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a & b | c ": [Or, Identifier("c"), EOF],
    "a & c ^ d": [Xor, Identifier("d"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AndExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//exclusiveOrExpression
//    : andExpression ('^' andExpression)*
//    ;

///|
pub struct ExclusiveOrExpr {
  exprs : Array[AndExpr]
} derive(Show, Eq)

///|
fn ExclusiveOrExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ExclusiveOrExpr, ArrayView[Token]) raise {
  let exprs : Array[AndExpr] = Array::new()
  let (first_expr, rest_toks) = AndExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Xor, .. rest_toks] => {
      let (next_expr, rest) = AndExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let exclusive_or_expr = ExclusiveOrExpr::{ exprs, }
  (exclusive_or_expr, rest_toks)
}

///|
test "ExclusiveOrExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "1 & a ^ b ? c": [Question, Identifier("c"), EOF],
    "d ^ e & 1 ? f": [Question, Identifier("f"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ExclusiveOrExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//inclusiveOrExpression
//    : exclusiveOrExpression ('|' exclusiveOrExpression)*
//    ;

///|
pub struct InclusiveOrExpr {
  exprs : Array[ExclusiveOrExpr]
} derive(Show, Eq)

///|
fn InclusiveOrExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (InclusiveOrExpr, ArrayView[Token]) raise {
  let exprs : Array[ExclusiveOrExpr] = Array::new()
  let (first_expr, rest_toks) = ExclusiveOrExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Or, .. rest_toks] => {
      let (next_expr, rest) = ExclusiveOrExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let inclusive_or_expr = InclusiveOrExpr::{ exprs, }
  (inclusive_or_expr, rest_toks)
}

///|
test "InclusiveOrExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a | b ? c": [Question, Identifier("c"), EOF],
    "d | e ? f": [Question, Identifier("f"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    //let toks = lex(code)
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = InclusiveOrExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//logicalAndExpression
//    : inclusiveOrExpression ('&&' inclusiveOrExpression)*
//    ;

///|
pub struct LogicalAndExpr {
  exprs : Array[InclusiveOrExpr]
} derive(Show, Eq)

///|
fn LogicalAndExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (LogicalAndExpr, ArrayView[Token]) raise {
  let exprs : Array[InclusiveOrExpr] = Array::new()
  let (first_expr, rest_toks) = InclusiveOrExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [DoubleAnd, .. rest_toks] => {
      let (next_expr, rest) = InclusiveOrExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let logical_and_expr = LogicalAndExpr::{ exprs, }
  (logical_and_expr, rest_toks)
}

///|
test "LogicalAndExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a && b || c": [DoubleOr, Identifier("c"), EOF],
    "d && e || f": [DoubleOr, Identifier("f"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = LogicalAndExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//logicalOrExpression
//    : logicalAndExpression ('||' logicalAndExpression)*
//    ;

///|
pub struct LogicalOrExpr {
  exprs : Array[LogicalAndExpr]
} derive(Show, Eq)

///|
fn LogicalOrExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (LogicalOrExpr, ArrayView[Token]) raise {
  let exprs : Array[LogicalAndExpr] = Array::new()
  let (first_expr, rest_toks) = LogicalAndExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [DoubleOr, .. rest_toks] => {
      let (next_expr, rest) = LogicalAndExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let logical_or_expr = LogicalOrExpr::{ exprs, }
  (logical_or_expr, rest_toks)
}

///|
test "LogicalOrExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a || b ? c": [Question, Identifier("c"), EOF],
    "d || e ? f": [Question, Identifier("f"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = LogicalOrExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//conditionalExpression
//    : logicalOrExpression ('?' expression ':' conditionalExpression)?
//    ;

///|
pub struct ConditionalExpr {
  expr : LogicalOrExpr
  select : (Expr, ConditionalExpr)?
} derive(Show, Eq)

///|
fn ConditionalExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ConditionalExpr, ArrayView[Token]) raise {
  let (logical_or_expr, rest_toks) = LogicalOrExpr::parse(toks, ctx)
  match rest_toks {
    [Question, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [Colon, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected ':' after expression in conditional expression",
          ),
        )
      }
      let (conditional_expr, rest_toks) = ConditionalExpr::parse(rest_toks, ctx)
      let conditional_expr = ConditionalExpr::{
        expr: logical_or_expr,
        select: Some((expr, conditional_expr)),
      }
      (conditional_expr, rest_toks)
    }
    _ => {
      let conditional_expr = ConditionalExpr::{
        expr: logical_or_expr,
        select: None,
      }
      (conditional_expr, rest_toks)
    }
  }
}

///|
test "ConditionalExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "cond1 ? 123 : 456 ; int": [Semi, Int, EOF],
    "cond1 && cond2 ? abc : def ; struct": [Semi, Struct, EOF],
    "init || Next ? 7 : 8; ": [Semi, EOF],
    "a123 += 5": [PlusAssign, Constant(Constant::Int(5)), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ConditionalExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "ConditionalExpr Parsing Negative Test" {
  let code = "cond1 ? 123 ;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? ConditionalExpr::parse(toks, ctx)) is Err(ParseError((3, _))),
  )
}

//assignmentExpression
//    : conditionalExpression
//    | unaryExpression assignmentOperator assignmentExpression
//    | DigitSequence // for
//    ;

///|
pub enum AssignExpr {
  Conditional(ConditionalExpr)
  Assign(UnaryExpr, AssignOp, AssignExpr)
} derive(Show, Eq)

///|
fn AssignExpr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (AssignExpr, ArrayView[Token]) raise {
  let (cond_expr, rest_toks) = ConditionalExpr::parse(toks, ctx)
  if !rest_toks[0].is_assign_op() {
    return (AssignExpr::Conditional(cond_expr), rest_toks)
  }
  let (unary_expr, rest_toks) = UnaryExpr::parse(toks, ctx)
  match rest_toks {
    [
      Assign
      | PlusAssign
      | MinusAssign
      | StarAssign
      | DivAssign
      | ModAssign
      | LeftShiftAssign
      | RightShiftAssign
      | AndAssign
      | OrAssign
      | BitXorAssign
      | BitAndAssign
      | BitOrAssign as op,
      .. rest_toks,
    ] => {
      let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx)
      let assign_op = match op {
        Assign => AssignOp::Assign
        PlusAssign => AssignOp::AddAssign
        MinusAssign => AssignOp::SubAssign
        StarAssign => AssignOp::MultAssign
        DivAssign => AssignOp::DivAssign
        ModAssign => AssignOp::ModAssign
        AndAssign => AssignOp::AndAssign
        OrAssign => AssignOp::OrAssign
        LeftShiftAssign => AssignOp::LeftShiftAssign
        RightShiftAssign => AssignOp::RightShiftAssign
        BitAndAssign => AssignOp::BitwiseAndAssign
        BitXorAssign => AssignOp::BitwiseXorAssign
        _ => AssignOp::BitwiseOrAssign // BitOrAssign
      }
      (AssignExpr::Assign(unary_expr, assign_op, assign_expr), rest_toks)
    }
    _ => {
      let (cond_expr, rest_toks) = ConditionalExpr::parse(toks, ctx)
      (AssignExpr::Conditional(cond_expr), rest_toks)
    }
  }
}

///|
test "AssignExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a = b + c; int": [Semi, Int, EOF],
    "x += 5; union": [Semi, Union, EOF],
    "cond1 && cond2 ? abc : def ; struct": [Semi, Struct, EOF],
    "a -= 1;": [Semi, EOF],
    "b *= 2;": [Semi, EOF],
    "c /= 3;": [Semi, EOF],
    "d %= 4;": [Semi, EOF],
    "e <<= 5;": [Semi, EOF],
    "f >>= 6;": [Semi, EOF],
    "g &= 7;": [Semi, EOF],
    "h |= 8;": [Semi, EOF],
    "i ^= 9;": [Semi, EOF],
    "j &&= l;": [Semi, EOF],
    "k ||= m;": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AssignExpr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub enum AssignOp {
  Assign // =
  AddAssign // +=
  SubAssign // -=
  MultAssign // *=
  DivAssign // /=
  ModAssign // %=
  AndAssign // &&=
  OrAssign // ||=
  LeftShiftAssign // <<=
  RightShiftAssign // >>=
  BitwiseAndAssign // &=
  BitwiseXorAssign // ^=
  BitwiseOrAssign // |=
} derive(Show, Eq)

//expression
//    : assignmentExpression (',' assignmentExpression)*
//    ;

///|
pub(all) struct Expr {
  exprs : Array[AssignExpr]
} derive(Show, Eq)

///|
fn Expr::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Expr, ArrayView[Token]) raise {
  let exprs : Array[AssignExpr] = Array::new()
  let (first_expr, rest_toks) = AssignExpr::parse(toks, ctx)
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_expr, rest) = AssignExpr::parse(rest_toks, ctx)
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let expr = Expr::{ exprs, }
  (expr, rest_toks)
}

///|
test "Expr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a = b + c, d = e - f; int": [Semi, Int, EOF],
    "x += 5, y -= 10; union": [Semi, Union, EOF],
    "cond1 && cond2 ? abc : def ; struct": [Semi, Struct, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Expr::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub typealias ConditionalExpr as ConstantExpr

//declaration
//    : declarationSpecifiers initDeclaratorList? ';'
//    | staticAssertDeclaration
//    ;

///|
pub enum Declaration {
  Decl(Array[DeclSpec], Array[InitDeclarator])
  //StaticAssertDecl(StaticAssertDecl)
} derive(Show, Eq)

///|
fn Declaration::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Declaration, ArrayView[Token]) raise {
  let is_typedef = toks is [Typedef, ..]
  let (decl_specs, rest_toks) = DeclSpecList::parse(toks, ctx)
  let decl_specs = decl_specs.0
  guard decl_specs.length() > 0 else {
    let idx = ctx.alltoks.length() - rest_toks.length()
    raise ParseError(
      (idx, "Parse Error: Declaration specifiers cannot be empty"),
    )
  }
  let (declaration, rest_toks) = match rest_toks {
    [Semi, .. rest_toks] => {
      let declaration = Declaration::Decl(decl_specs, Array::new())
      (declaration, rest_toks)
    }
    _ => {
      let (init_decls, rest) = InitDeclaratorList::parse(rest_toks, ctx)
      let declaration = Declaration::Decl(decl_specs, init_decls.0)
      guard rest is [Semi, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError((idx, "Parse Error: Expected ';' after declaration"))
      }
      (declaration, rest_toks)
    }
  }
  if is_typedef {
    let inits = match declaration {
      Declaration::Decl(_, inits) => inits
      //_ => raise ParseError("Expected declaration in typedef")
    }
    inits.each(i => ctx.add_typedef(i.get_ident()))
  }
  (declaration, rest_toks)
}

///|
test "Declaration Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int a;": [EOF],
    "const char *p;": [EOF],
    "static int x = 10;": [EOF],
    "extern void func(int, int);": [EOF],
    "typedef int MyInt;": [EOF],
    "struct Point { int x; int y; };": [EOF],
    "typedef struct { int a; int b; } MyStruct;": [EOF],
    "typedef double *p, *const q;": [EOF],
    "typedef int IntArr[];": [EOF],
    "typedef int IntArr[10];": [EOF],
    "typedef int (*BinaryFunc)(int, int);": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Declaration::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub(all) enum DeclSpec {
  StorageClassSpec(StorageClassSpec)
  TypeSpec(TypeSpec)
  TypeQualifier(TypeQualifier)
  FunctionSpec(FunctionSpec)
  AlignmentSpec(AlignmentSpec)
} derive(Show, Eq)

///|
fn DeclSpec::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (DeclSpec, ArrayView[Token]) raise {
  match toks {
    [Auto | Register | Static | ThreadLocal | Extern | Typedef, ..] => {
      let (storage_class_spec, rest_toks) = StorageClassSpec::parse(toks, ctx)
      (DeclSpec::StorageClassSpec(storage_class_spec), rest_toks)
    }
    [Const | Volatile | Restrict | Atomic as q, .. rest_toks] => {
      let type_qualifier = match q {
        Const => TypeQualifier::Const
        Volatile => TypeQualifier::Volatile
        Restrict => TypeQualifier::Restrict
        _ => TypeQualifier::Atomic
      }
      (DeclSpec::TypeQualifier(type_qualifier), rest_toks)
    }
    [Inline, .. rest_toks] => (DeclSpec::FunctionSpec(Inline), rest_toks)
    [Noreturn, .. rest_toks] => (DeclSpec::FunctionSpec(Noreturn), rest_toks)
    [Attribute, LParen, LParen, .. rest_toks] => {
      let (attr_list, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parentheses after attribute list",
          ),
        )
      }
      let spec = DeclSpec::FunctionSpec(
        FunctionSpec::Attributes(attr_list.exprs),
      )
      (spec, rest)
    }
    [Alignas, LParen, .. rest_toks] => {
      let (expr, rest) = ConstantExpr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after expression in _Alignas",
          ),
        )
      }
      let spec = AlignmentSpec::AlignasExpr(expr)
      (DeclSpec::AlignmentSpec(spec), rest)
    }
    [Alignas, .. rest_toks] => {
      let idx = ctx.alltoks.length() - rest_toks.length()
      raise ParseError((idx, "Parse Error: Expected '(' after _Alignas"))
    }
    [Alignof, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after type name in _Alignof",
          ),
        )
      }
      let spec = AlignmentSpec::AlignofType(type_name)
      (DeclSpec::AlignmentSpec(spec), rest)
    }
    [Alignof, .. rest_toks] => {
      let idx = ctx.alltoks.length() - rest_toks.length()
      raise ParseError((idx, "Parse Error: Expected '(' after _Alignof"))
    }
    _ => {
      let (type_spec, rest_toks) = TypeSpec::parse(toks, ctx)
      (DeclSpec::TypeSpec(type_spec), rest_toks)
    }
  }
}

///|
priv struct DeclSpecList(Array[DeclSpec])

///|
fn DeclSpecList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (DeclSpecList, ArrayView[Token]) raise {
  let decl_specs : Array[DeclSpec] = Array::new()
  loop toks {
    [Auto | Register | Static | ThreadLocal | Extern | Typedef, ..] as toks => {
      let (storage_class_spec, rest_toks) = StorageClassSpec::parse(toks, ctx)
      decl_specs.push(DeclSpec::StorageClassSpec(storage_class_spec))
      continue rest_toks
    }
    [Atomic, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after type name in _Atomic",
          ),
        )
      }
      let type_spec = TypeSpec::Atomic(type_name)
      let decl_spec = DeclSpec::TypeSpec(type_spec)
      decl_specs.push(decl_spec)
      continue rest
    }
    [Const | Volatile | Restrict | Atomic as q, .. rest_toks] => {
      let type_qualifier = match q {
        Const => TypeQualifier::Const
        Volatile => TypeQualifier::Volatile
        Restrict => TypeQualifier::Restrict
        _ => TypeQualifier::Atomic
      }
      let decl_spec = DeclSpec::TypeQualifier(type_qualifier)
      decl_specs.push(decl_spec)
      continue rest_toks
    }
    [Inline, .. rest_toks] => {
      let decl_spec = DeclSpec::FunctionSpec(Inline)
      decl_specs.push(decl_spec)
      continue rest_toks
    }
    [Noreturn, .. rest_toks] => {
      let decl_spec = DeclSpec::FunctionSpec(Noreturn)
      decl_specs.push(decl_spec)
      continue rest_toks
    }
    [Attribute, LParen, LParen, .. rest_toks] => {
      let (attr_list, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parentheses after attribute list",
          ),
        )
      }
      let spec = DeclSpec::FunctionSpec(
        FunctionSpec::Attributes(attr_list.exprs),
      )
      decl_specs.push(spec)
      continue rest
    }
    [Alignas, LParen, .. rest_toks] => {
      let (expr, rest) = ConstantExpr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after expression in _Alignas",
          ),
        )
      }
      let spec = AlignmentSpec::AlignasExpr(expr)
      let decl_spec = DeclSpec::AlignmentSpec(spec)
      decl_specs.push(decl_spec)
      continue rest
    }
    [Alignas, .. rest_toks] => {
      let idx = ctx.alltoks.length() - rest_toks.length()
      raise ParseError((idx, "Parse Error: Expected '(' after _Alignas"))
    }
    [Alignof, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after type name in _Alignof",
          ),
        )
      }
      let spec = AlignmentSpec::AlignofType(type_name)
      let decl_spec = DeclSpec::AlignmentSpec(spec)
      decl_specs.push(decl_spec)
      continue rest
    }
    [Alignof, .. rest_toks] => {
      let idx = ctx.alltoks.length() - rest_toks.length()
      raise ParseError((idx, "Parse Error: Expected '(' after _Alignof"))
    }
    [
      Void
      | Char
      | Short
      | Int
      | Long
      | Float
      | Double
      | Signed
      | Unsigned
      | Bool
      | Complex
      | Struct
      | Union
      | Enum,
      ..,
    ] as toks => {
      let (type_spec, rest_toks) = TypeSpec::parse(toks, ctx)
      let decl_spec = DeclSpec::TypeSpec(type_spec)
      decl_specs.push(decl_spec)
      continue rest_toks
    }
    [Identifier(name), .. rest_toks] if ctx.typedefs.contains(name) => {
      let type_spec = TypeSpec::TypedefName(name)
      let decl_spec = DeclSpec::TypeSpec(type_spec)
      decl_specs.push(decl_spec)
      continue rest_toks
    }
    toks => break (decl_specs, toks)
    //[Identifier(_) | Star, ..] as toks => {
    //  break (decl_specs, toks)
    //}
    //toks => {
    //  let idx = ctx.alltoks.length() - toks.length()
    //  raise ParseError((idx, "Parse Error: Unimplemented declaration specifier, \{toks[0]}, loc = \{loc}"))
    //}
  }
}

///|
test "DeclSpecList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int a;": [Identifier("a"), Semi, EOF],
    "long long int p;": [Identifier("p"), Semi, EOF],
    "const char *p;": [Star, Identifier("p"), Semi, EOF],
    "volatile int x;": [Identifier("x"), Semi, EOF],
    "restrict int y;": [Identifier("y"), Semi, EOF],
    "_Atomic int z;": [Identifier("z"), Semi, EOF],
    "inline void f()": [Identifier("f"), LParen, RParen, EOF],
    "_Noreturn void g()": [Identifier("g"), LParen, RParen, EOF],
    "_Alignas(16) struct S { int x; };": [Semi, EOF],
    "_Alignof(int) a;": [Identifier("a"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DeclSpecList::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // negative test
  let code = "_Alignas 16 int a;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? DeclSpec::parse(toks, ctx)) is Err(ParseError((1, _))))
}

///|
pub enum StorageClassSpec {
  Auto // auto
  Register // register
  Static // static
  ThreadLocal // _Thread_local
  Extern // extern
  Typedef // typedef
} derive(Show, Eq)

///|
fn StorageClassSpec::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (StorageClassSpec, ArrayView[Token]) raise {
  match toks {
    [Auto, .. rest_toks] => (StorageClassSpec::Auto, rest_toks)
    [Register, .. rest_toks] => (StorageClassSpec::Register, rest_toks)
    [Static, .. rest_toks] => (StorageClassSpec::Static, rest_toks)
    [ThreadLocal, .. rest_toks] => (StorageClassSpec::ThreadLocal, rest_toks)
    [Extern, .. rest_toks] => (StorageClassSpec::Extern, rest_toks)
    [Typedef, .. rest_toks] => (StorageClassSpec::Typedef, rest_toks)
    _ => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (idx, "Parse Error: Unimplemented storage class specifier"),
      )
    }
  }
}

///|
test "StorageClassSpec Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "auto a;": [Identifier("a"), Semi, EOF],
    "register b;": [Identifier("b"), Semi, EOF],
    "static c;": [Identifier("c"), Semi, EOF],
    "_Thread_local d;": [Identifier("d"), Semi, EOF],
    "extern e;": [Identifier("e"), Semi, EOF],
    "typedef f;": [Identifier("f"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StorageClassSpec::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // negative test
  let code = "int a;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? StorageClassSpec::parse(toks, ctx)) is Err(ParseError((0, _))),
  )
}

//typeSpecifier
//    : 'void'
//    | 'char'
//    | 'short'
//    | 'int'
//    | 'long'
//    | 'float'
//    | 'double'
//    | 'signed'
//    | 'unsigned'
//    | '_Bool'
//    | '_Complex'
//    | '__m128'
//    | '__m128d'
//    | '__m128i'
//    | '__extension__' '(' ('__m128' | '__m128d' | '__m128i') ')'
//    | atomicTypeSpecifier
//    | structOrUnionSpecifier
//    | enumSpecifier
//    | typedefName
//    | '__typeof__' '(' constantExpression ')' // GCC extension
//    ;

///|
pub enum TypeSpec {
  Void // void
  Char // char
  Short // short
  Int // int
  Long // long
  Float // float
  Double // double
  Signed // signed
  Unsigned // unsigned
  Bool // _Bool
  Complex // _Complex
  Atomic(TypeName) // _Atomic(type)
  StructSpec(StructSpec)
  UnionSpec(UnionSpec)
  EnumSpec(EnumSpec)
  TypedefName(String)
} derive(Show, Eq)

///|
fn TypeSpec::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (TypeSpec, ArrayView[Token]) raise {
  match toks {
    [Void, .. rest_toks] => (TypeSpec::Void, rest_toks)
    [Char, .. rest_toks] => (TypeSpec::Char, rest_toks)
    [Short, .. rest_toks] => (TypeSpec::Short, rest_toks)
    [Int, .. rest_toks] => (TypeSpec::Int, rest_toks)
    [Long, .. rest_toks] => (TypeSpec::Long, rest_toks)
    [Float, .. rest_toks] => (TypeSpec::Float, rest_toks)
    [Double, .. rest_toks] => (TypeSpec::Double, rest_toks)
    [Signed, .. rest_toks] => (TypeSpec::Signed, rest_toks)
    [Unsigned, .. rest_toks] => (TypeSpec::Unsigned, rest_toks)
    [Bool, .. rest_toks] => (TypeSpec::Bool, rest_toks)
    [Complex, .. rest_toks] => (TypeSpec::Complex, rest_toks)
    [Atomic, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after type name in _Atomic",
          ),
        )
      }
      (TypeSpec::Atomic(type_name), rest)
    }
    [Struct, ..] as toks => {
      let (struct_spec, rest_toks) = StructSpec::parse(toks, ctx)
      (TypeSpec::StructSpec(struct_spec), rest_toks)
    }
    [Union, ..] as toks => {
      let (union_spec, rest_toks) = UnionSpec::parse(toks, ctx)
      (TypeSpec::UnionSpec(union_spec), rest_toks)
    }
    [Enum, ..] as toks => {
      let (enum_spec, rest_toks) = EnumSpec::parse(toks, ctx)
      (TypeSpec::EnumSpec(enum_spec), rest_toks)
    }
    [Identifier(name), .. rest_toks] if ctx.typedefs.contains(name) =>
      (TypeSpec::TypedefName(name), rest_toks)
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (idx, "Parse Error: Parse TypeSpec Error, unexpect token \{toks[0]}"),
      )
    }
  }
}

///|
test "TypeSpec Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "void a;": [Identifier("a"), Semi, EOF],
    "char b;": [Identifier("b"), Semi, EOF],
    "short c;": [Identifier("c"), Semi, EOF],
    "int d;": [Identifier("d"), Semi, EOF],
    "long e;": [Identifier("e"), Semi, EOF],
    "float f;": [Identifier("f"), Semi, EOF],
    "double g;": [Identifier("g"), Semi, EOF],
    "signed h;": [Identifier("h"), Semi, EOF],
    "unsigned i;": [Identifier("i"), Semi, EOF],
    "_Bool j;": [Identifier("j"), Semi, EOF],
    "_Complex k;": [Identifier("k"), Semi, EOF],
    "_Atomic(int) l;": [Identifier("l"), Semi, EOF],
    "struct Point { double x, y;};": [Semi, EOF],
    "union MyUnion { int x; float y;};": [Semi, EOF],
    "enum Color { Red, Green };": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = TypeSpec::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "TypeSpec Parsing Negative Test" {
  let code = "_Atomic(int a;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? TypeSpec::parse(toks, ctx)) is Err(ParseError((3, _))))
  let code = "MyInt a;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? TypeSpec::parse(toks, ctx)) is Err(ParseError((0, _))))
}

///|
pub enum TypeQualifier {
  Const // const
  Volatile // volatile
  Restrict // restrict
  Atomic // _Atomic
} derive(Show, Eq)

///|
struct TypeQualifierList(Array[TypeQualifier]) derive(Show, Eq)

///|
fn TypeQualifierList::parse(
  toks : ArrayView[Token],
) -> (TypeQualifierList, ArrayView[Token]) {
  let qualifiers : Array[TypeQualifier] = Array::new()
  let rest_toks = loop toks {
    [Const, .. rest_toks] => {
      qualifiers.push(TypeQualifier::Const)
      continue rest_toks
    }
    [Volatile, .. rest_toks] => {
      qualifiers.push(TypeQualifier::Volatile)
      continue rest_toks
    }
    [Restrict, .. rest_toks] => {
      qualifiers.push(TypeQualifier::Restrict)
      continue rest_toks
    }
    [Atomic, .. rest_toks] => {
      qualifiers.push(TypeQualifier::Atomic)
      continue rest_toks
    }
    toks => break toks // no more type qualifiers
  }
  (TypeQualifierList(qualifiers), rest_toks)
}

///|
test "TypeQualifierList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "const int a;": [Int, Identifier("a"), Semi, EOF],
    "volatile char b;": [Char, Identifier("b"), Semi, EOF],
    "restrict double c;": [Double, Identifier("c"), Semi, EOF],
    "_Atomic int d;": [Int, Identifier("d"), Semi, EOF],
    "const volatile int e;": [Int, Identifier("e"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = TypeQualifierList::parse(toks)
    assert_eq(rest_toks, expect_rest)
  }
}

//fn TypeQualifierList::is_empty(self: Self) -> Bool {
//  self.0.is_empty()
//}

///|
pub enum TypeSpecOrQualifier {
  TypeSpec(TypeSpec)
  TypeQualifier(TypeQualifier)
} derive(Show, Eq)

///|
fn TypeSpecOrQualifier::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (TypeSpecOrQualifier, ArrayView[Token]) raise {
  match toks {
    [Const, .. rest_toks] =>
      (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Const), rest_toks)
    [Volatile, .. rest_toks] =>
      (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Volatile), rest_toks)
    [Restrict, .. rest_toks] =>
      (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Restrict), rest_toks)
    [Atomic, .. rest_toks] =>
      (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Atomic), rest_toks)
    _ => {
      let (type_spec, rest) = TypeSpec::parse(toks, ctx)
      (TypeSpecOrQualifier::TypeSpec(type_spec), rest)
    }
  }
}

///|
priv struct TypeSpecOrQualifierList(Array[TypeSpecOrQualifier])

///|
fn TypeSpecOrQualifierList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (TypeSpecOrQualifierList, ArrayView[Token]) {
  let specs : Array[TypeSpecOrQualifier] = Array::new()
  let mut toks = toks
  while (try? TypeSpecOrQualifier::parse(toks, ctx)) is Ok((spec, rest)) {
    specs.push(spec)
    toks = rest
  }
  (TypeSpecOrQualifierList(specs), toks)
}

///|
test "TypeSpecOrQualifierList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int f;": [Identifier("f"), Semi, EOF],
    "const int a;": [Identifier("a"), Semi, EOF],
    "volatile char b;": [Identifier("b"), Semi, EOF],
    "restrict double c;": [Identifier("c"), Semi, EOF],
    "_Atomic int d;": [Identifier("d"), Semi, EOF],
    "const volatile int e;": [Identifier("e"), Semi, EOF],
    "struct { double a, b;} p;": [Identifier("p"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = TypeSpecOrQualifierList::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub struct StructSpec {
  name : String?
  decls : Array[StructDeclaration]
} derive(Show, Eq)

///|
fn StructSpec::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (StructSpec, ArrayView[Token]) raise {
  guard toks is [Struct, .. toks] else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected 'struct' keyword for struct specification"),
    )
  }

  // Special case: struct name without body
  // for example:
  // - `struct Point;`
  // - `struct Point p;`
  // - `struct Point *p;`
  if toks is [Identifier(name), .. rtoks] && not(rtoks is [LBrace, ..]) {
    return (StructSpec::{ name: Some(name), decls: Array::new() }, toks[1:])
  }
  let (name, rest_toks) = match toks {
    [Identifier(name), LBrace, .. rest_toks] => (Some(name), rest_toks)
    [LBrace, .. rest_toks] => (None, rest_toks) // No name specified
    _ => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (idx, "Parse Error: Expected identifier or '{' after 'struct'"),
      )
    }
  }
  let decls : Array[StructDeclaration] = Array::new()
  let rest_toks = loop rest_toks {
    [RBrace, .. rest_toks] => break rest_toks
    [Semi, .. rest_toks] =>
      // Empty declaration, just skip it
      continue rest_toks
    rest_toks => {
      let (struct_decl, rest_toks) = StructDeclaration::parse(rest_toks, ctx)
      decls.push(struct_decl)
      continue rest_toks
    }
  }
  let struct_spec = StructSpec::{ name, decls }
  (struct_spec, rest_toks)
}

///|
test "StructSpec Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "struct MyStruct { int a; double b; }": [EOF],
    "struct { char c; }": [EOF],
    "struct EmptyStruct {}": [EOF],
    "struct AnotherStruct { int x;; }": [EOF],
    "struct Point p;": [Identifier("p"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StructSpec::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "StructSpec Parsing Negative Test" {
  let code = "strut MyStruct { int a; double b; };"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? StructSpec::parse(toks, ctx)) is Err(ParseError((0, _))))
  let code = "struct Point { int x; )"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? StructSpec::parse(toks, ctx)) is Err(ParseError((6, _))))
  let code = "struct int {};"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? StructSpec::parse(toks, ctx)) is Err(ParseError((1, _))))
}

///|
pub struct UnionSpec {
  name : String?
  decls : Array[StructDeclaration]
} derive(Show, Eq)

///|
fn UnionSpec::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (UnionSpec, ArrayView[Token]) raise {
  guard toks is [Union, .. toks] else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected 'union' keyword for union specification"),
    )
  }

  // Special case: struct name without body
  // for example:
  // - `struct Point;`
  // - `struct Point p;`
  // - `struct Point *p;`
  if toks is [Identifier(name), Identifier(_) | Star | Semi, ..] {
    return (UnionSpec::{ name: Some(name), decls: Array::new() }, toks[1:])
  }
  let (name, rest_toks) = match toks {
    [Identifier(name), LBrace, .. rest_toks] => (Some(name), rest_toks)
    [LBrace, .. rest_toks] => (None, rest_toks) // No name specified
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Expected identifier or '{' after 'union', current token: \{toks[0]}",
        ),
      )
    }
  }
  let decls : Array[StructDeclaration] = Array::new()
  let rest_toks = loop rest_toks {
    [RBrace, .. rest_toks] => break rest_toks
    [Semi, .. rest_toks] =>
      // Empty declaration, just skip it
      continue rest_toks
    rest_toks => {
      let (struct_decl, rest_toks) = StructDeclaration::parse(rest_toks, ctx)
      decls.push(struct_decl)
      continue rest_toks
    }
  }
  let union_spec = UnionSpec::{ name, decls }
  (union_spec, rest_toks)
}

///|
test "UnionSpec Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "union MyUnion { int a; double b; }": [EOF],
    "union { char c; }": [EOF],
    "union EmptyUnion {}": [EOF],
    "union AnotherUnion { int x;; }": [EOF],
    "union Point p;": [Identifier("p"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = UnionSpec::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
test "UnionSpec Parsing Negative Test" {
  let code = "unoin MyUnion { int a; double b; };"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? UnionSpec::parse(toks, ctx)) is Err(ParseError((0, _))))
  let code = "union Point { int x; )"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? UnionSpec::parse(toks, ctx)) is Err(ParseError((6, _))))
  let code = "union int {};"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? UnionSpec::parse(toks, ctx)) is Err(ParseError((1, _))))
}

//structDeclaration // The first two rules have priority order and cannot be simplified to one expression.
//    : specifierQualifierList structDeclaratorList ';'
//    | specifierQualifierList ';'
//    | staticAssertDeclaration
//    ;

///|
pub enum StructDeclaration {
  Normal(Array[TypeSpecOrQualifier], Array[StructDeclarator])
  //StaticAssertDecl(StaticAssertDecl)
} derive(Show, Eq)

///|
fn StructDeclaration::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (StructDeclaration, ArrayView[Token]) raise {
  let (type_spec_or_qualifiers, rest_toks) = TypeSpecOrQualifierList::parse(
    toks, ctx,
  )
  let type_spec_or_qualifiers = type_spec_or_qualifiers.0
  if rest_toks is [Semi, .. rest_toks] {
    // Case: specifierQualifierList ';'
    return (
      StructDeclaration::Normal(type_spec_or_qualifiers, Array::new()),
      rest_toks,
    )
  }
  let (struct_declarators, rest_toks) = StructDeclaratorList::parse(
    rest_toks, ctx,
  )
  guard rest_toks is [Semi, .. rest] else {
    let idx = ctx.alltoks.length() - rest_toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected ';' after struct declarators"),
    )
  }
  (
    StructDeclaration::Normal(type_spec_or_qualifiers, struct_declarators.0),
    rest,
  )
}

///|
test "StructDeclaration Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int a, b;": [EOF],
    "double x;": [EOF],
    "int a : 1, b : 2;": [EOF],
    "struct Point ;": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StructDeclaration::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // Negative test
  let code = "struct Point p:"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? StructDeclaration::parse(toks, ctx)) is Err(ParseError((4, _))),
  )
}

///|
pub enum StructDeclarator {
  Declarator(Declarator)
  Field(Declarator?, ConstantExpr)
} derive(Show, Eq)

//structDeclarator
//    : declarator
//    | declarator? ':' constantExpression
//    ;

///|
fn StructDeclarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (StructDeclarator, ArrayView[Token]) raise {
  if toks is [Colon, .. rest_toks] {
    let (const_expr, rest_toks) = ConstantExpr::parse(rest_toks, ctx)
    return (StructDeclarator::Field(None, const_expr), rest_toks)
  }
  let (declarator, rest_toks) = Declarator::parse(toks, ctx)
  match rest_toks {
    [Colon, .. rest_toks] => {
      let (const_expr, rest_toks) = ConstantExpr::parse(rest_toks, ctx)
      (StructDeclarator::Field(Some(declarator), const_expr), rest_toks)
    }
    _ => (StructDeclarator::Declarator(declarator), rest_toks)
  }
}

///|
priv struct StructDeclaratorList(Array[StructDeclarator])

///|
fn StructDeclaratorList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (StructDeclaratorList, ArrayView[Token]) raise {
  let decls : Array[StructDeclarator] = Array::new()
  let (first_decl, rest_toks) = StructDeclarator::parse(toks, ctx)
  decls.push(first_decl)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_decl, rest) = StructDeclarator::parse(rest_toks, ctx)
      decls.push(next_decl)
      continue rest
    }
    toks => break toks // no more struct declarators
  }
  (StructDeclaratorList(decls), rest_toks)
}

///|
test "StructDeclaratorList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a ;": [Semi, EOF],
    "a, b ;": [Semi, EOF],
    "a : 1, b : 2 ;": [Semi, EOF],
    ": 1": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StructDeclaratorList::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub struct Declarator {
  pointer : Pointer?
  directDeclarator : DirectDeclarator
  gccDeclExt : Array[Expr] // GCC attributes, e.g., `__attribute__((aligned(16)))
} derive(Show, Eq)

///|
pub fn Declarator::get_ident(self : Self) -> String {
  self.directDeclarator.get_ident()
}

///|
fn Declarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Declarator, ArrayView[Token]) raise {
  let (pointer, rest_toks) = Pointer::parse(toks)
  let pointer = if pointer.0.is_empty() {
    None // No pointer qualifiers
  } else {
    Some(pointer)
  }
  let (direct_declarator, rest) = DirectDeclarator::parse(rest_toks, ctx)
  let gccDeclExt : Array[Expr] = Array::new()
  let rest_toks = loop rest {
    [Attribute, LParen, LParen, .. rest_toks] => {
      let (gcc_decl_ext_expr, rest_toks) = Expr::parse(rest_toks, ctx)
      guard rest_toks is [RParen, RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest_toks.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing parentheses for GCC attribute"),
        )
      }
      gccDeclExt.push(gcc_decl_ext_expr)
      continue rest_toks
    }
    toks => break toks // no more GCC attributes
  }
  (
    Declarator::{ pointer, directDeclarator: direct_declarator, gccDeclExt },
    rest_toks,
  )
}

///|
test "Declarator Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a": [EOF],
    "*b": [EOF],
    "**c": [EOF],
    "* const Point": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Declarator::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//pointer
//    : ('*' typeQualifierList?)+
//    ;
// for example:
//  * : [[]]
//  * const : [[Const]]
//  * const volatile : [[Const, Volatile]]
//  * const * volatile : [[Const], [Volatile]]
//  * const * restrict *: [[Const], [Restrict], []]

///|
pub struct Pointer(Array[Array[TypeQualifier]]) derive(Show, Eq)

///|
fn Pointer::parse(toks : ArrayView[Token]) -> (Pointer, ArrayView[Token]) {
  let quals : Array[Array[TypeQualifier]] = Array::new()
  let rest_toks = loop toks {
    [Star, .. rest_toks] => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(rest_toks)
      quals.push(type_qualifiers.0)
      continue rest_toks
    }
    toks => break toks
  }
  (Pointer(quals), rest_toks)
}

///|
test "Pointer Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "*a": [Identifier("a"), EOF],
    "**b": [Identifier("b"), EOF],
    "*volatile *restrict c": [Identifier("c"), EOF],
    "** _Atomic d": [Identifier("d"), EOF],
    "* const Point": [Identifier("Point"), EOF],
    "* const volatile * restrict * e": [Identifier("e"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Pointer::parse(toks)
    assert_eq(rest_toks, expect_rest)
  }
}

//directDeclarator
//    : Identifier
//    | '(' declarator ')'
//    | directDeclarator '[' typeQualifierList? assignmentExpression? ']'
//    | directDeclarator '[' 'static' typeQualifierList? assignmentExpression ']'
//    | directDeclarator '[' typeQualifierList 'static' assignmentExpression ']'
//    | directDeclarator '[' typeQualifierList? '*' ']'
//    | directDeclarator '(' parameterTypeList ')'
//    | directDeclarator '(' identifierList? ')'
//    | Identifier ':' DigitSequence         // bit field
//    | vcSpecificModifer Identifier         // Visual C Extension
//    | '(' vcSpecificModifer declarator ')' // Visual C Extension
//    ;

///|
pub enum DirectDeclarator {
  Identifier(String)
  Parenthesized(Declarator)
  Array(DirectDeclarator, TypeQualifierList, AssignExpr?)
  StaticArray(DirectDeclarator, Array[TypeQualifier], AssignExpr)
  VallengthArray(DirectDeclarator, Array[TypeQualifier])
  FunctionDecl(DirectDeclarator, ParameterTypeList)
  FunctionPtr(DirectDeclarator, Array[String])
  BitField(String, Int)
} derive(Show, Eq)

///|
pub fn DirectDeclarator::get_ident(self : Self) -> String {
  match self {
    DirectDeclarator::Identifier(name) => name
    Array(inner, _, _) => inner.get_ident()
    StaticArray(inner, _, _) => inner.get_ident()
    VallengthArray(inner, _) => inner.get_ident()
    FunctionDecl(inner, _) => inner.get_ident()
    FunctionPtr(inner, _) => inner.get_ident()
    BitField(name, _) => name
    Parenthesized(inner) => inner.get_ident()
  }
}

///|
fn DirectDeclarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (DirectDeclarator, ArrayView[Token]) raise {
  if toks is [Identifier(name), Colon, Constant(Int(i)), .. rest_toks] {
    // BitField case
    return (DirectDeclarator::BitField(name, i), rest_toks)
  }
  let (head_decl, rest_toks) = match toks {
    [Identifier(name), .. rest_toks] =>
      (DirectDeclarator::Identifier(name), rest_toks)
    [LParen, .. rest_toks] => {
      let (declarator, rest) = Declarator::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing parenthesis after declarator"),
        )
      }
      (DirectDeclarator::Parenthesized(declarator), rest)
    }
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented direct declarator parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
  let mut current_decl = head_decl
  loop rest_toks {
    [LBracket, Static, .. rest_toks] => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(rest_toks)
      let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing bracket after static array declaration",
          ),
        )
      }
      current_decl = DirectDeclarator::StaticArray(
        current_decl,
        type_qualifiers.0,
        assign_expr,
      )
      continue rest_toks
    }
    [LBracket, .. rest_toks] => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(rest_toks)
      let rest_toks = match rest_toks {
        [Static, .. rest_toks] => {
          let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
          current_decl = DirectDeclarator::StaticArray(
            current_decl,
            type_qualifiers.0,
            assign_expr,
          )
          guard rest is [RBracket, .. rest_toks] else {
            let idx = ctx.alltoks.length() - rest.length()
            raise ParseError(
              (
                idx, "Parse Error: Expected closing bracket after static array declaration",
              ),
            )
          }
          rest_toks
        }
        [Star, .. rest] => {
          current_decl = DirectDeclarator::VallengthArray(
            current_decl,
            type_qualifiers.0,
          )
          guard rest is [RBracket, .. rest_toks] else {
            let idx = ctx.alltoks.length() - rest.length()
            raise ParseError(
              (
                idx, "Parse Error: Expected closing bracket after variable length array declaration",
              ),
            )
          }
          rest_toks
        }
        [RBracket, .. rest_toks] => {
          current_decl = DirectDeclarator::Array(
            current_decl,
            type_qualifiers.0,
            None,
          )
          rest_toks
        }
        _ => {
          let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
          current_decl = DirectDeclarator::Array(
            current_decl,
            type_qualifiers.0,
            Some(assign_expr),
          )
          guard rest is [RBracket, .. rest_toks] else {
            let idx = ctx.alltoks.length() - rest.length()
            raise ParseError(
              (
                idx, "Parse Error: Expected closing bracket after array declaration",
              ),
            )
          }
          rest_toks
        }
      }
      continue rest_toks
    }
    // IdentifierList
    [LParen, Identifier(name), Comma, .. rest_toks] => {
      let identifiers : Array[String] = [name]
      let rest_toks = loop rest_toks {
        [Identifier(next_name), .. rest_toks] => {
          identifiers.push(next_name)
          continue rest_toks
        }
        [Comma, .. rest_toks] => continue rest_toks
        [RParen, .. rest_toks] => break rest_toks
        _ => {
          let idx = ctx.alltoks.length() - toks.length()
          raise ParseError(
            (
              idx, "Parse Error: Expected identifier or closing parenthesis in identifier list",
            ),
          )
        }
      }
      current_decl = DirectDeclarator::FunctionPtr(current_decl, identifiers)
      continue rest_toks
    }
    // IdentifierList
    [LParen, Identifier(name), RParen, .. rest_toks] => {
      let identifiers : Array[String] = [name]
      current_decl = DirectDeclarator::FunctionPtr(current_decl, identifiers)
      continue rest_toks
    }
    [LParen, RParen, .. rest_toks] => {
      current_decl = DirectDeclarator::FunctionPtr(current_decl, [])
      continue rest_toks
    }
    // parameterTypeList
    [LParen, .. rest_toks] => {
      let (params, rest) = ParameterTypeList::parse(rest_toks, ctx)
      current_decl = DirectDeclarator::FunctionDecl(current_decl, params)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after parameter type list",
          ),
        )
      }
      continue rest_toks
    }
    rest_toks => break (current_decl, rest_toks) // No more direct declarators
  }
}

///|
test "DirectDeclarator Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "arr ;": [Semi, EOF],
    "fact() ;": [Semi, EOF],
    "fact(int a) ;": [Semi, EOF],
    "fib(int a, int b) ;": [Semi, EOF],
    "fib(a, b) ;": [Semi, EOF], // K & R style
    "arr[] ;": [Semi, EOF],
    "arr[10] ;": [Semi, EOF],
    "arr[static const 10] ;": [Semi, EOF],
    "arr[const static 10] ;": [Semi, EOF],
    "arr[static 10] ;": [Semi, EOF],
    "arr[*];": [Semi, EOF],
    "arr[len];": [Semi, EOF],
    "(*fptr)(int, int) ;": [Semi, EOF],
    "r: 4 ;": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DirectDeclarator::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // Negative test
  let code = "(*fptr](int, int);"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? DirectDeclarator::parse(toks, ctx)) is Err(_))
  let code = "fib(int a, int b;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? DirectDeclarator::parse(toks, ctx)) is Err(_))
}

//initDeclarator
//    : declarator ('=' initializer)?
//    ;

///|
pub struct InitDeclarator {
  declarator : Declarator
  initializer : Initializer?
} derive(Show, Eq)

///|
fn InitDeclarator::get_ident(self : Self) -> String {
  self.declarator.get_ident()
}

///|
fn InitDeclarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (InitDeclarator, ArrayView[Token]) raise {
  let (declarator, rest_toks) = Declarator::parse(toks, ctx)
  if rest_toks is [Assign, .. rest_toks] {
    let (initializer, rest_toks) = Initializer::parse(rest_toks, ctx)
    (InitDeclarator::{ declarator, initializer: Some(initializer) }, rest_toks)
  } else {
    (InitDeclarator::{ declarator, initializer: None }, rest_toks)
  }
}

///|
test "InitDeclarator Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a;": [Semi, EOF],
    "b = 10;": [Semi, EOF],
    "arr[] = {1, 2, 3, 4, 5};": [Semi, EOF],
    "*p = 4;": [Semi, EOF],
    "*p;": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = InitDeclarator::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
priv struct InitDeclaratorList(Array[InitDeclarator])

///|
fn InitDeclaratorList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (InitDeclaratorList, ArrayView[Token]) raise {
  let decls : Array[InitDeclarator] = Array::new()
  let (first_decl, rest_toks) = InitDeclarator::parse(toks, ctx)
  decls.push(first_decl)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_decl, rest) = InitDeclarator::parse(rest_toks, ctx)
      decls.push(next_decl)
      continue rest
    }
    toks => break toks // no more init declarators
  }
  (InitDeclaratorList(decls), rest_toks)
}

//initializer
//    : assignmentExpression
//    | '{' initializerList ','? '}'
//    ;
//
//initializerList
//    : designation? initializer (',' designation? initializer)*
//    ;
//
//designation
//    : designatorList '='
//    ;
//
//designatorList
//    : designator+
//    ;
//
//designator
//    : '[' constantExpression ']'
//    | '.' Identifier
//    ;

///|
pub enum Initializer {
  AssignExpr(AssignExpr)
  InitList(Array[(Array[Designator], Initializer)])
} derive(Show, Eq)

///|
fn Initializer::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Initializer, ArrayView[Token]) raise {
  match toks {
    [LBrace, ..] as toks => {
      let (init_list, rest) = InitializerList::parse(toks, ctx)
      (Initializer::InitList(init_list.0), rest)
    }
    _ => {
      let (assign_expr, rest) = AssignExpr::parse(toks, ctx)
      (Initializer::AssignExpr(assign_expr), rest)
    }
  }
}

///|
pub struct InitializerList(Array[(Array[Designator], Initializer)]) derive (
  Eq,
  Show,
)

///|
fn InitializerList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (InitializerList, ArrayView[Token]) raise {
  guard toks is [LBrace, .. toks] else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected '{' to start initializer list"),
    )
  }
  let init_list : Array[(Array[Designator], Initializer)] = Array::new()
  loop toks {
    [Dot | LBracket, ..] as toks => {
      let (designators, rest) = DesignatorList::parse(toks, ctx)
      guard rest is [Assign, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected '=' after designator list in initializer",
          ),
        )
      }
      let (initializer, rest) = Initializer::parse(rest, ctx)
      init_list.push((designators.0, initializer))
      continue rest
    }
    [Comma, .. rest_toks] =>
      // Skip commas
      continue rest_toks
    [RBrace, .. rest_toks] =>
      // End of initializer list
      break (InitializerList(init_list), rest_toks)
    toks => {
      // If we reach here, it means we have an initializer without designators
      let (initializer, rest) = Initializer::parse(toks, ctx)
      init_list.push((Array::new(), initializer))
      continue rest
    }
  }
}

///|
test "InitializerList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "{1, 2, 3}": [EOF],
    "{.field = 1, .other = 2}": [EOF],
    "{[0] = 1, [1] = 2}": [EOF],
    "{.field = {1, 2}, .other = {3}}": [EOF],
    "{{1, 2}, {3, 4}}": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = InitializerList::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // negative test
  let code = "1, 2}"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? InitializerList::parse(toks, ctx)) is Err(ParseError((0, _))),
  )
  let code = "{ .f += 3 }"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? InitializerList::parse(toks, ctx)) is Err(ParseError((3, _))),
  )
}

//designator
//    : '[' constantExpression ']'
//    | '.' Identifier
//    ;

///|
pub enum Designator {
  ConstExpr(ConstantExpr)
  DotAccess(String)
} derive(Show, Eq)

///|
fn Designator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Designator, ArrayView[Token]) raise {
  match toks {
    [LBracket, .. rest_toks] => {
      let (const_expr, rest) = ConstantExpr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing bracket after constant expression in designator",
          ),
        )
      }
      (Designator::ConstExpr(const_expr), rest)
    }
    [Dot, Identifier(name), .. rest_toks] =>
      (Designator::DotAccess(name), rest_toks)
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented designator parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
priv struct DesignatorList(Array[Designator])

///|
fn DesignatorList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (DesignatorList, ArrayView[Token]) raise {
  let designators : Array[Designator] = Array::new()
  let rest_toks = loop toks {
    [LBracket | Dot, ..] as toks => {
      let (designator, rest) = Designator::parse(toks, ctx)
      designators.push(designator)
      continue rest
    }
    toks => break toks // no more designators
  }
  (DesignatorList(designators), rest_toks)
}

///|
test "DesignatorList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "[0]": [EOF],
    ".field": [EOF],
    "[1].field": [EOF],
    "[2][3].field": [EOF],
    "[1].field[2]": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DesignatorList::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//enumSpecifier
//    : 'enum' Identifier? '{' enumeratorList ','? '}'
//    | 'enum' Identifier
//    ;
//
//enumeratorList
//    : enumerator (',' enumerator)*
//    ;
//
//enumerator
//    : enumerationConstant ('=' constantExpression)?
//    ;
//
//enumerationConstant
//    : Identifier
//    ;

///|
pub struct EnumSpec {
  name : String?
  enumerators : Array[Enumerator]
} derive(Show, Eq)

///|
fn EnumSpec::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (EnumSpec, ArrayView[Token]) raise {
  guard toks is [Enum, .. toks] else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected 'enum' keyword for enum specification"),
    )
  }
  match toks {
    [Identifier(name), LBrace, RBrace, .. rest_toks] =>
      // Anonymous enum with no enumerators
      (EnumSpec::{ name: Some(name), enumerators: Array::new() }, rest_toks)
    [Identifier(name), LBrace, .. rest_toks] => {
      let (enumerators, rest) = EnumeratorList::parse(rest_toks, ctx)
      let enumerators = enumerators.0
      guard rest is [RBrace, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing brace after enumerator list in enum specification",
          ),
        )
      }
      (EnumSpec::{ name: Some(name), enumerators }, rest_toks)
    }
    [Identifier(name), .. rest_toks] =>
      (EnumSpec::{ name: Some(name), enumerators: Array::new() }, rest_toks)
    [LBrace, RBrace, .. rest_toks] =>
      // Anonymous enum with no enumerators
      (EnumSpec::{ name: None, enumerators: Array::new() }, rest_toks)
    [LBrace, .. rest_toks] => {
      // Anonymous enum
      let (enumerators, rest) = EnumeratorList::parse(rest_toks, ctx)
      let enumerators = enumerators.0
      guard rest is [RBrace, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing brace after enumerator list in anonymous enum",
          ),
        )
      }
      (EnumSpec::{ name: None, enumerators }, rest_toks)
    }
    _ => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented enum specification parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
test "EnumSpec Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "enum MyEnum { A, B, C }": [EOF],
    "enum { Red, Yellow, Blue }": [EOF],
    "enum EmptyEnum {}": [EOF],
    "enum AnotherEnum { ONE = 1, TWO = 2 }": [EOF],
    "enum SingleEnum { ONLY }": [EOF],
    "enum AnaEnum ;": [Semi, EOF],
    "enum {}; ": [Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = EnumSpec::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // negative test
  let code = "struct Point ;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? EnumSpec::parse(toks, ctx)) is Err(ParseError((0, _))))
  let code = "enum { A; "
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? EnumSpec::parse(toks, ctx)) is Err(ParseError((3, _))))
  let code = "enum int a; "
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true((try? EnumSpec::parse(toks, ctx)) is Err(ParseError((1, _))))
}

///|
pub struct Enumerator(String, ConstantExpr?) derive(Show, Eq)

///|
fn Enumerator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Enumerator, ArrayView[Token]) raise {
  match toks {
    [Identifier(name), Assign, .. rest_toks] => {
      let (const_expr, rest_toks) = ConstantExpr::parse(rest_toks, ctx)
      (Enumerator(name, Some(const_expr)), rest_toks)
    }
    [Identifier(name), .. rest_toks] => (Enumerator(name, None), rest_toks)
    _ => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented enumerator parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
priv struct EnumeratorList(Array[Enumerator])

///|
fn EnumeratorList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (EnumeratorList, ArrayView[Token]) raise {
  let enumerators : Array[Enumerator] = Array::new()
  let (first_enum, rest_toks) = Enumerator::parse(toks, ctx)
  enumerators.push(first_enum)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_enum, rest) = Enumerator::parse(rest_toks, ctx)
      enumerators.push(next_enum)
      continue rest
    }
    [RBrace, ..] as toks => break toks // End of enumerator list
    rest_toks => {
      let idx = ctx.alltoks.length() - rest_toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Expected comma or closing brace in enumerator list, current token: \{rest_toks[0]}",
        ),
      )
    }
  }
  (enumerators, rest_toks)
}

//functionSpecifier
//    : 'inline'
//    | '_Noreturn'
//    | '__inline__' // GCC extension
//    | '__stdcall'
//    | gccAttributeSpecifier
//    | '__declspec' '(' Identifier ')'
//    ;

///|
pub enum FunctionSpec {
  Inline // inline
  Noreturn // _Noreturn
  Attributes(Array[AssignExpr]) // __attribute__((...))
} derive(Show, Eq)

///|
pub enum AlignmentSpec {
  AlignasExpr(ConstantExpr) // _Alignas(expr)
  AlignofType(TypeName) // _Alignof(type)
} derive(Show, Eq)

//typeName
//    : specifierQualifierList abstractDeclarator?
//    ;

///|
pub struct TypeName {
  specifiers : Array[TypeSpecOrQualifier]
  abstract_declarator : AbstractDeclarator?
} derive(Show, Eq)

///|
fn TypeName::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (TypeName, ArrayView[Token]) raise {
  let specifiers : Array[TypeSpecOrQualifier] = Array::new()
  let mut rest_toks = toks
  while (try? TypeSpecOrQualifier::parse(rest_toks, ctx)) is Ok((spec, rest)) {
    specifiers.push(spec)
    rest_toks = rest
  }
  if specifiers.is_empty() {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected type specifier or qualifier in TypeName"),
    )
  }
  let (abstract_declarator, rest_toks) = if rest_toks
    is [Star | LParen | LBracket, ..] {
    let (a, rest) = AbstractDeclarator::parse(rest_toks, ctx)
    (Some(a), rest)
  } else {
    (None, rest_toks)
  }
  if specifiers.is_empty() && abstract_declarator is None {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError((idx, "Parse Error: InValud TypeName."))
  }
  let type_name = TypeName::{ specifiers, abstract_declarator }
  (type_name, rest_toks)
}

///|
test "TypeName Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int *ptr": [Identifier("ptr"), EOF],
    "char **str": [Identifier("str"), EOF],
    "const char ** msg": [Identifier("msg"), EOF],
    "int const * arr": [Identifier("arr"), EOF],
    "int * const arr": [Identifier("arr"), EOF],
    "struct Point p;": [Identifier("p"), Semi, EOF],
  }
  for code, expect_rest in code_expect_rest {
    //let toks = lex(code)
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = TypeName::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//abstractDeclarator
//    : pointer
//    | pointer? directAbstractDeclarator gccDeclaratorExtension*
//    ;

///|
pub struct AbstractDeclarator {
  pointer : Pointer?
  directAbstractDeclarator : DirectAbstractDeclarator?
} derive(Show, Eq)

///|
fn AbstractDeclarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (AbstractDeclarator, ArrayView[Token]) raise {
  match toks {
    [Star, ..] => {
      let (pointer, rest_toks) = Pointer::parse(toks)
      let (direct_abstract_declarator, rest_toks) = DirectAbstractDeclarator::parse(
        rest_toks, ctx,
      )
      let abstract_declarator = AbstractDeclarator::{
        pointer: Some(pointer),
        directAbstractDeclarator: direct_abstract_declarator,
      }
      (abstract_declarator, rest_toks)
    }
    [LParen | LBracket, ..] as toks => {
      let (direct_abstract_declarator, rest_toks) = DirectAbstractDeclarator::parse(
        toks, ctx,
      )
      let abstract_declarator = AbstractDeclarator::{
        pointer: None,
        directAbstractDeclarator: direct_abstract_declarator,
      }
      (abstract_declarator, rest_toks)
    }
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented abstract declarator parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
test "AbstractDeclarator Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "*": [EOF],
    "[*]": [EOF],
    "[10]": [EOF],
    "[a][10]": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AbstractDeclarator::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//
//directAbstractDeclarator
//    : '(' abstractDeclarator ')' gccDeclaratorExtension*
//    | '[' typeQualifierList? assignmentExpression? ']'
//    | '[' 'static' typeQualifierList? assignmentExpression ']'
//    | '[' typeQualifierList 'static' assignmentExpression ']'
//    | '[' '*' ']'
//    | '(' parameterTypeList? ')' gccDeclaratorExtension*
//    | directAbstractDeclarator '[' typeQualifierList? assignmentExpression? ']'
//    | directAbstractDeclarator '[' 'static' typeQualifierList? assignmentExpression ']'
//    | directAbstractDeclarator '[' typeQualifierList 'static' assignmentExpression ']'
//    | directAbstractDeclarator '[' '*' ']'
//    | directAbstractDeclarator '(' parameterTypeList? ')' gccDeclaratorExtension*
//    ;

///|
pub enum DirectAbstractDeclarator {
  FuncDecl(DirectAbstractDeclarator?, ParameterTypeList)
  ArrayDecl(
    DirectAbstractDeclarator?,
    is_static~ : Bool,
    Array[TypeQualifier],
    AssignExpr?
  ) // Bool indicates if it's a static array
  InCompleteArray(DirectAbstractDeclarator?) // '[' '*' ']'
  FuncPtr(DirectAbstractDeclarator?, AbstractDeclarator)
} derive(Show, Eq)

// TODO: Not Correct Implementation

///|
fn DirectAbstractDeclarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (DirectAbstractDeclarator?, ArrayView[Token]) raise {
  let (head_decl, rest_toks) = match toks {
    [LParen, Star | LBracket | LParen, ..] as toks => {
      let (abstract_declarator, rest) = AbstractDeclarator::parse(toks[1:], ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after abstract declarator",
          ),
        )
      }
      (DirectAbstractDeclarator::FuncPtr(None, abstract_declarator), rest_toks)
    }
    [LParen, .. rest_toks] => {
      let (parameter_type_list, rest) = ParameterTypeList::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after parameter type list",
          ),
        )
      }
      (DirectAbstractDeclarator::FuncDecl(None, parameter_type_list), rest_toks)
    }
    [LBracket, Star, RBracket, .. rest_toks] =>
      (DirectAbstractDeclarator::InCompleteArray(None), rest_toks)
    [LBracket, Static, ..] as toks => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(toks[2:])
      let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing bracket after static array declaration",
          ),
        )
      }
      (
        DirectAbstractDeclarator::ArrayDecl(
          None,
          is_static=true,
          type_qualifiers.0,
          Some(assign_expr),
        ),
        rest_toks,
      )
    }
    [LBracket, tok, ..] as toks if ctx.is_declspec_tok(tok) => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(toks[1:])
      let (is_static, rest_toks) = if rest_toks is [Static, ..] {
        (true, rest_toks[1:])
      } else {
        (false, rest_toks)
      }
      let (assign_expr, rest_toks) = if !(rest_toks[0] is RBracket) {
        let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx)
        (Some(assign_expr), rest_toks)
      } else {
        (None, rest_toks)
      }
      guard rest_toks is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest_toks.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing bracket after array declaration"),
        )
      }
      (
        DirectAbstractDeclarator::ArrayDecl(
          None,
          is_static~,
          type_qualifiers.0,
          assign_expr,
        ),
        rest_toks,
      )
    }
    [LBracket, RBracket, .. rest_toks] =>
      (
        DirectAbstractDeclarator::ArrayDecl(
          None,
          is_static=false,
          Array::new(),
          None,
        ),
        rest_toks,
      )
    [LBracket, .. rest_toks] => {
      let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing bracket after array declaration"),
        )
      }
      (
        DirectAbstractDeclarator::ArrayDecl(
          None,
          is_static=false,
          Array::new(),
          Some(assign_expr),
        ),
        rest_toks,
      )
    }
    toks => return (None, toks) // No direct abstract declarator
  }
  let mut curr_decl = head_decl
  loop rest_toks {
    [LParen, .. rest_toks] => {
      let (parameter_type_list, rest) = ParameterTypeList::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after parameter type list",
          ),
        )
      }
      curr_decl = DirectAbstractDeclarator::FuncDecl(
        Some(curr_decl),
        parameter_type_list,
      )
      continue rest_toks
    }
    [LBracket, Star, RBracket, .. rest_toks] => {
      curr_decl = DirectAbstractDeclarator::InCompleteArray(Some(curr_decl))
      continue rest_toks
    }
    [LBracket, Static, ..] as toks => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(toks[2:])
      let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing bracket after static array declaration",
          ),
        )
      }
      curr_decl = DirectAbstractDeclarator::ArrayDecl(
        Some(curr_decl),
        is_static=true,
        type_qualifiers.0,
        Some(assign_expr),
      )
      continue rest_toks
    }
    [LBracket, tok, ..] as toks if ctx.is_declspec_tok(tok) => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(toks[1:])
      let (is_static, rest_toks) = if rest_toks is [Static, ..] {
        (true, rest_toks[1:])
      } else {
        (false, rest_toks)
      }
      let (assign_expr, rest_toks) = if !(rest_toks is [RBracket, ..]) {
        let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx)
        (Some(assign_expr), rest_toks)
      } else {
        (None, rest_toks)
      }
      curr_decl = DirectAbstractDeclarator::ArrayDecl(
        Some(curr_decl),
        is_static~,
        type_qualifiers.0,
        assign_expr,
      )
      continue rest_toks
    }
    [LBracket, RBracket, .. rest_toks] => {
      curr_decl = DirectAbstractDeclarator::ArrayDecl(
        Some(curr_decl),
        is_static=false,
        Array::new(),
        None,
      )
      continue rest_toks
    }
    [LBracket, .. rest_toks] => {
      let (assign_expr, rest) = AssignExpr::parse(rest_toks, ctx)
      guard rest is [RBracket, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing bracket after array declaration"),
        )
      }
      curr_decl = DirectAbstractDeclarator::ArrayDecl(
        Some(curr_decl),
        is_static=false,
        Array::new(),
        Some(assign_expr),
      )
      continue rest_toks
    }
    rest_toks => break (Some(curr_decl), rest_toks) // No more direct abstract declarators
  }
}

///|
test "DirectAbstractDeclarator Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "(*)(int, int)": [EOF],
    "[*]": [EOF],
    "[]": [EOF],
    "[static 10]": [EOF],
    "[const static 10]": [EOF],
    "[static const 10]": [EOF],
    "[static 5][10]": [EOF],
    "(int, int)": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DirectAbstractDeclarator::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//statement
//    : labeledStatement
//    | compoundStatement
//    | expressionStatement
//    | selectionStatement
//    | iterationStatement
//    | jumpStatement
//    | ('__asm' | '__asm__') ('volatile' | '__volatile__') '(' (
//        logicalOrExpression (',' logicalOrExpression)*
//    )? (':' (logicalOrExpression (',' logicalOrExpression)*)?)* ')' ';'
//    ;

///|
pub enum Statement {
  Empty // Empty statement, just a semicolon
  LabeledStatement(LabeledStatement)
  CompoundStatement(CompoundStatement)
  ExpressionStatement(Expr)
  SelectionStatement(SelectionStatement)
  IterationStatement(IterationStatement)
  JumpStatement(JumpStatement)
  // Asm
  // volatile
} derive(Show, Eq)

///|
fn Statement::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (Statement, ArrayView[Token]) raise {
  match toks {
    [LBrace, ..] as toks => {
      let (compound_statement, rest_toks) = CompoundStatement::parse(toks, ctx)
      (Statement::CompoundStatement(compound_statement), rest_toks)
    }
    [If | Switch, ..] as toks => {
      let (selection_statement, rest_toks) = SelectionStatement::parse(
        toks, ctx,
      )
      (Statement::SelectionStatement(selection_statement), rest_toks)
    }
    [For | While | Do, ..] as toks => {
      let (iteration_statement, rest_toks) = IterationStatement::parse(
        toks, ctx,
      )
      (Statement::IterationStatement(iteration_statement), rest_toks)
    }
    [Identifier(_), Colon, ..] as toks => {
      let (labeled_statement, rest_toks) = LabeledStatement::parse(toks, ctx)
      (Statement::LabeledStatement(labeled_statement), rest_toks)
    }
    [Case | Default, ..] as toks => {
      let (labeled_statement, rest_toks) = LabeledStatement::parse(toks, ctx)
      (Statement::LabeledStatement(labeled_statement), rest_toks)
    }
    [Goto | Continue | Break | Return, ..] as toks => {
      let (jump_statement, rest_toks) = JumpStatement::parse(toks, ctx)
      (Statement::JumpStatement(jump_statement), rest_toks)
    }
    [Semi, .. rest_toks] => (Statement::Empty, rest_toks)
    _ => {
      let (expr, rest) = Expr::parse(toks, ctx)
      guard rest is [Semi, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected ';' after expression statement"),
        )
      }
      (Statement::ExpressionStatement(expr), rest_toks)
    }
  }
}

///|
test "Statement Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "x = 10;": [EOF],
    "if (x) { y++; }": [EOF],
    "while (x < 10) { x++; }": [EOF],
    "for (int i = 0; i < 10; i++) { sum += i; }": [EOF],
    //"goto label;" : [EOF],
    //"label: x = 10;" : [EOF],
    //"{ int a; }" : [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Statement::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//labeledStatement
//    : Identifier ':' statement
//    | 'case' constantExpression ':' statement
//    | 'default' ':' statement
//    ;

///|
pub enum LabeledStatement {
  Label(String, Statement)
  Case(ConstantExpr, Statement)
  Default(Statement)
} derive(Show, Eq)

///|
fn LabeledStatement::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (LabeledStatement, ArrayView[Token]) raise {
  match toks {
    [Identifier(name), Colon, .. rest_toks] => {
      let (statement, rest_toks) = Statement::parse(rest_toks, ctx)
      (LabeledStatement::Label(name, statement), rest_toks)
    }
    [Case, .. rest_toks] => {
      let (const_expr, rest) = ConstantExpr::parse(rest_toks, ctx)
      guard rest is [Colon, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected ':' after case constant expression"),
        )
      }
      let (statement, rest_toks) = Statement::parse(rest_toks, ctx)
      (LabeledStatement::Case(const_expr, statement), rest_toks)
    }
    [Default, Colon, .. rest_toks] => {
      let (statement, rest_toks) = Statement::parse(rest_toks, ctx)
      (LabeledStatement::Default(statement), rest_toks)
    }
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented labeled statement parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
test "LabeledStatement Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "label: x = 10;": [EOF],
    "case 1: y++;": [EOF],
    "default: z--;": [EOF],
    "myLabel: if (x) { y++; }": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = LabeledStatement::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // negative test
  let code = "case 5 ;"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? LabeledStatement::parse(toks, ctx)) is Err(ParseError((2, _))),
  )
  let code = "int :"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? LabeledStatement::parse(toks, ctx)) is Err(ParseError((0, _))),
  )
}

///|
pub struct CompoundStatement {
  items : Array[BlockItem]
} derive(Show, Eq)

///|
fn CompoundStatement::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (CompoundStatement, ArrayView[Token]) raise {
  guard toks is [LBrace, .. toks] else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError((idx, "Parse Error: Expected '{' for compound statement"))
  }
  ctx.enter_scope()
  let items : Array[BlockItem] = Array::new()
  loop toks {
    [RBrace, .. rest_toks] => {
      ctx.leave_scope()
      break (CompoundStatement::{ items, }, rest_toks) // End of compound statement
    }
    [Semi, .. rest_toks] =>
      // Empty statement, just skip it
      continue rest_toks
    toks => {
      let (item, rest_toks) = BlockItem::parse(toks, ctx)
      items.push(item)
      continue rest_toks
    }
  }
}

///|
test "CompoundStatement Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "{ int a; }": [EOF],
    "{ int a; int b; }": [EOF],
    "{ int a = 1, b = 2; c = a + b;}": [EOF],
    "{ if (x) { y++; } else { y--; } }": [EOF],
    "{ while (x < 10) { x++; } }": [EOF],
    "{ for (int i = 0; i < 10; i++) { sum += i; } }": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = CompoundStatement::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }

  // negative test
  let code = "if (x) { y++; }"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? CompoundStatement::parse(toks, ctx)) is Err(ParseError((0, _))),
  )
}

///|
pub enum BlockItem {
  Statement(Statement)
  Declaration(Declaration)
} derive(Show, Eq)

///|
fn BlockItem::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (BlockItem, ArrayView[Token]) raise {
  if ctx.is_declspec_tok(toks[0]) {
    let (decl, rest_toks) = Declaration::parse(toks, ctx)
    (BlockItem::Declaration(decl), rest_toks)
  } else {
    let (stmt, rest_toks) = Statement::parse(toks, ctx)
    (BlockItem::Statement(stmt), rest_toks)
  }
}

///|
pub enum SelectionStatement {
  If(Expr, Statement, Statement?)
  Switch(Expr, Statement)
} derive(Show, Eq)

///|
fn SelectionStatement::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (SelectionStatement, ArrayView[Token]) raise {
  match toks {
    [If, LParen, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected closing parenthesis after if condition"),
        )
      }
      let (then_stmt, rest_toks) = Statement::parse(rest_toks, ctx)
      let (else_stmt, rest_toks) = if rest_toks is [Else, .. rest_toks] {
        let (else_stmt, rest_toks) = Statement::parse(rest_toks, ctx)
        (Some(else_stmt), rest_toks)
      } else {
        (None, rest_toks)
      }
      (SelectionStatement::If(expr, then_stmt, else_stmt), rest_toks)
    }
    [Switch, LParen, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after switch condition",
          ),
        )
      }
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx)
      (SelectionStatement::Switch(expr, stmt), rest_toks)
    }
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented selection statement parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
test "SelectionStatement Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "if (x < 10) { x++; } else { x--; }": [EOF],
    "if (x < 10) { x++; }": [EOF],
    "switch (x) { case 1: y++; break; default: y--; }": [EOF],
    "switch (x) { case 1: y++; }": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = SelectionStatement::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
  let code = "switch n { case 1: y++; }"
  let ctx = ParserContext::create_by_code(code)
  ctx.tokenize()
  let toks = ctx.alltoks
  assert_true(
    (try? SelectionStatement::parse(toks, ctx)) is Err(ParseError((0, _))),
  )
}

///|
pub enum IterationStatement {
  While(Expr, Statement)
  DoWhile(Statement, Expr)
  For(ForCondition, Statement)
} derive(Show, Eq)

///|
fn IterationStatement::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (IterationStatement, ArrayView[Token]) raise {
  match toks {
    [While, LParen, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis after while condition",
          ),
        )
      }
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx)
      (IterationStatement::While(expr, stmt), rest_toks)
    }
    [Do, .. rest_toks] => {
      let (stmt, rest) = Statement::parse(rest_toks, ctx)
      guard rest is [While, LParen, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected 'while' after do-while statement"),
        )
      }
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [RParen, Semi, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (
            idx, "Parse Error: Expected closing parenthesis and ';' after do-while condition",
          ),
        )
      }
      (IterationStatement::DoWhile(stmt, expr), rest_toks)
    }
    [For, ..] => {
      let (for_cond, rest_toks) = ForCondition::parse(toks, ctx)
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx)
      (IterationStatement::For(for_cond, stmt), rest_toks)
    }
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented iteration statement parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
test "IterationStatement Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "while (x < 10) { x++; }": [EOF],
    "do { x++; } while (x < 10);": [EOF],
    "for (int i = 0; i < 10; i++) { sum += i; }": [EOF],
    "for (int i = 0;;) { sum += i; }": [EOF],
    "for (;;) { break; }": [EOF],
    "while (i < 10) i++;": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = IterationStatement::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//forCondition
//    : (forDeclaration | expression?) ';' forExpression? ';' forExpression?
//    ;

///|
pub struct ForCondition {
  for_init : ForInit
  cond : Array[AssignExpr]
  inc : Array[AssignExpr]
} derive(Show, Eq)

///|
fn ForCondition::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ForCondition, ArrayView[Token]) raise {
  guard toks is [For, LParen, .. toks] else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (idx, "Parse Error: Expected 'for' condition to start with 'for('"),
    )
  }
  let (for_init, rest_toks) = ForInit::parse(toks, ctx)
  let (cond, rest_toks) = if rest_toks is [Semi, .. rest_toks] {
    (Array::new(), rest_toks) // No condition
  } else {
    let (expr, rest) = Expr::parse(rest_toks, ctx)
    guard rest is [Semi, .. rest_toks] else {
      //raise ParseError("Expected ';' after for condition expression")
      let idx = ctx.alltoks.length() - rest.length()
      raise ParseError(
        (idx, "Parse Error: Expected ';' after for condition expression"),
      )
    }
    (expr.exprs, rest_toks)
  }
  let (inc, rest_toks) = if rest_toks is [RParen, .. rest_toks] {
    (Array::new(), rest_toks) // No increment
  } else {
    let (expr, rest) = Expr::parse(rest_toks, ctx)
    guard rest is [RParen, .. rest_toks] else {
      let idx = ctx.alltoks.length() - rest.length()
      raise ParseError(
        (
          idx, "Parse Error: Expected closing parenthesis and ';' after for increment expression",
        ),
      )
    }
    (expr.exprs, rest_toks)
  }
  let for_condition = ForCondition::{ for_init, cond, inc }
  (for_condition, rest_toks)
}

///|
pub enum ForInit {
  Declaration(Declaration)
  //InitDeclarators(Array[InitDeclarator])
  InitExpr(Expr)
  Empty
} derive(Show, Eq)

///|
fn ForInit::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ForInit, ArrayView[Token]) raise {
  match toks {
    [Semi, .. rest_toks] => (ForInit::Empty, rest_toks) // Empty initialization
    [tok, ..] if ctx.is_declspec_tok(tok) => {
      let (decl, rest_toks) = Declaration::parse(toks, ctx)
      (ForInit::Declaration(decl), rest_toks)
    }
    _ => {
      let (expr, rest_toks) = Expr::parse(toks, ctx)
      guard rest_toks is [Semi, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest_toks.length()
        raise ParseError(
          (idx, "Parse Error: Expected ';' after for initialization expression"),
        )
      }
      (ForInit::InitExpr(expr), rest_toks)
    }
  }
}

///|
test "ForCondition Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "for (int i = 0; i < 10; i++) ": [EOF],
    "for (int i = 0;;) ": [EOF],
    "for (;;)": [EOF],
    "for (i = 0; i < 10; i++) ": [EOF],
    "for (i = 0;;) ": [EOF],
    "for (;i < 0; i++) ": [EOF],
    "for (;i < 0;) ": [EOF],
    "for (;; i++) ": [EOF],
    "for (int i = 0, j = 1; i+j < 10;) ": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ForCondition::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub enum JumpStatement {
  Goto(String)
  Continue
  Break
  Return(Expr?)
} derive(Show, Eq)

///|
fn JumpStatement::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (JumpStatement, ArrayView[Token]) raise {
  match toks {
    [Goto, Identifier(name), Semi, .. rest_toks] =>
      (JumpStatement::Goto(name), rest_toks)
    [Continue, Semi, .. rest_toks] => (JumpStatement::Continue, rest_toks)
    [Break, Semi, .. rest_toks] => (JumpStatement::Break, rest_toks)
    [Return, Semi, .. rest_toks] => (JumpStatement::Return(None), rest_toks)
    [Return, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx)
      guard rest is [Semi, .. rest_toks] else {
        let idx = ctx.alltoks.length() - rest.length()
        raise ParseError(
          (idx, "Parse Error: Expected ';' after return expression"),
        )
      }
      (JumpStatement::Return(Some(expr)), rest_toks)
    }
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Unimplemented jump statement parsing, current token: \{toks[0]}",
        ),
      )
    }
  }
}

///|
test "Jump Statement Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "goto label;": [EOF],
    "continue;": [EOF],
    "break;": [EOF],
    "return;": [EOF],
    "return 42;": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = JumpStatement::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub struct CompilationUnit {
  externalDecls : Array[ExternalDeclaration]
} derive(Show, Eq)

///|
fn CompilationUnit::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> CompilationUnit raise {
  let external_decls : Array[ExternalDeclaration] = Array::new()
  loop toks {
    [EOF] => break CompilationUnit::{ externalDecls: external_decls } // End of input
    [Semi, .. rest_toks] =>
      // Empty declaration, just skip it
      continue rest_toks
    toks => {
      let (external_decl, rest_toks) = ExternalDeclaration::parse(toks, ctx)
      external_decls.push(external_decl)
      continue rest_toks
    }
  }
}

///|
test "CompilationUnit Parsing Test" {
  let codes = [
    "int main() { return 0; }", "float compute(float x, float y) { return x * y; }",
    //"typedef struct { int x; int y; } Point; Point* new(int, int);"
  ]
  for code in codes {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    assert_true(
      (try? CompilationUnit::parse(toks, ctx)) is Ok(_),
      msg="Failed to parse code: \{code}",
    )
  }
}

///|
pub enum ExternalDeclaration {
  FunctionDefinition(FunctionDefinition)
  Declaration(Declaration)
} derive(Show, Eq)

///|
fn ExternalDeclaration::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ExternalDeclaration, ArrayView[Token]) raise {
  try FunctionDefinition::parse(toks, ctx) catch {
    FunctionDefinitionParseError::CompoundStatementParseError(err) => raise err
    _ => {
      let (decl, rest_toks) = Declaration::parse(toks, ctx)
      (ExternalDeclaration::Declaration(decl), rest_toks)
    }
  } noraise {
    (func_def, rest_toks) =>
      (ExternalDeclaration::FunctionDefinition(func_def), rest_toks)
  }
}

///|
test "ExternalDeclaration Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int func(int a, char *b) { return a + b; }": [EOF],
    "void myFunc() { int x = 1, y = 0; return x * y; }": [EOF],
    "float compute(float x, float y) { return x * y; }": [EOF],
    "int a;": [EOF],
    //"char *str;" : [EOF],
    //"typedef struct { int x; int y; } Point;" : [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ExternalDeclaration::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//functionDefinition
//    : declarationSpecifiers declarator declarationList? compoundStatement
//    ;

///|
pub struct FunctionDefinition {
  declSpecs : Array[DeclSpec]
  declarator : Declarator
  kr_declarations : Array[Declaration]
  body : CompoundStatement
} derive(Show, Eq)

///|
pub suberror FunctionDefinitionParseError {
  DeclSpecsParseError(Error)
  DeclaratorParseError(Error)
  NotFunctionDefinitionError(Error)
  KRDeclarationParseError(Error)
  CompoundStatementParseError(Error)
}

///|
fn FunctionDefinition::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (FunctionDefinition, ArrayView[Token]) raise FunctionDefinitionParseError {
  let (decl_specs, rest_toks) = DeclSpecList::parse(toks, ctx) catch {
    err => raise FunctionDefinitionParseError::DeclSpecsParseError(err)
  }
  let (declarator, rest_toks) = Declarator::parse(rest_toks, ctx) catch {
    err => raise FunctionDefinitionParseError::DeclaratorParseError(err)
  }

  // if current tok is ';', it's not a function definition.
  if rest_toks is [Semi, ..] {
    let idx = ctx.alltoks.length() - rest_toks.length()
    raise NotFunctionDefinitionError(
      ParseError(
        (idx, "Parse Error: Expected function body after declarator, found ';'"),
      ),
    )
  }
  let (kr_declarations, rest_toks) = if !(rest_toks is [LBrace, ..]) {
    let decls : Array[Declaration] = Array::new()
    loop rest_toks {
      [LBrace, ..] as rest_toks => break (Array::new(), rest_toks) // No more kr_declarations
      [Semi, .. rest_toks] =>
        // Empty declaration, just skip it
        continue rest_toks
      rest_toks => {
        let (decl, rest_toks) = Declaration::parse(rest_toks, ctx) catch {
          err =>
            raise FunctionDefinitionParseError::KRDeclarationParseError(err)
        }
        decls.push(decl)
        continue rest_toks
      }
    }
  } else {
    (Array::new(), rest_toks) // No kr_declarations
  }
  let (body, rest_toks) = CompoundStatement::parse(rest_toks, ctx) catch {
    err => raise FunctionDefinitionParseError::CompoundStatementParseError(err)
  }
  let function_def = FunctionDefinition::{
    declSpecs: decl_specs.0,
    declarator,
    kr_declarations,
    body,
  }
  (function_def, rest_toks)
}

///|
test "FunctionDefinition Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int func(int a, char *b) { return a + b; }": [EOF],
    "void myFunc() { int x = 1, y = 0; return x * y; }": [EOF],
    "float compute(float x, float y) { return x * y; }": [EOF],
    "int main() { return 0; }": [EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = FunctionDefinition::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//parameterTypeList
//    : parameterList (',' '...')?
//    ;

///|
pub struct ParameterTypeList {
  params : Array[ParameterDecl]
  variadic : Bool
} derive(Show, Eq)

///|
fn ParameterTypeList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ParameterTypeList, ArrayView[Token]) raise {
  let (params, rest_toks) = ParameterList::parse(toks, ctx)
  let params = params.0
  match rest_toks {
    [Comma, Ellipsis, .. rest_toks] => {
      let param_type_list = ParameterTypeList::{ params, variadic: true }
      (param_type_list, rest_toks)
    }
    _ => {
      let param_type_list = ParameterTypeList::{ params, variadic: false }
      (param_type_list, rest_toks)
    }
  }
}

//parameterList
//    : parameterDeclaration (',' parameterDeclaration)*
//    ;

///|
priv struct ParameterList(Array[ParameterDecl])

///|
fn ParameterList::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ParameterList, ArrayView[Token]) raise {
  let decls : Array[ParameterDecl] = Array::new()
  let (first_decl, rest_toks) = ParameterDecl::parse(toks, ctx)
  decls.push(first_decl)
  let rest_toks = loop rest_toks {
    // Ellipsis is handled in ParameterTypeList
    [Comma, Ellipsis, ..] as rest_toks => break rest_toks
    [Comma, .. rest_toks] => {
      let (next_decl, rest) = ParameterDecl::parse(rest_toks, ctx)
      decls.push(next_decl)
      continue rest
    }
    [RParen, ..] as rest_toks => break rest_toks // End of parameter list
    toks => {
      let idx = ctx.alltoks.length() - toks.length()
      raise ParseError(
        (
          idx,
          "Parse Error: Expected ',' or ')' in parameter list, current token is \{toks[0]}",
        ),
      )
    }
  }
  let param_list = ParameterList(decls)
  (param_list, rest_toks)
}

///|
test "ParameterList Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int a, char *b, const int c, float d)": [RParen, EOF],
    "int a, char *b)": [RParen, EOF],
    "const int c)": [RParen, EOF],
    "float d)": [RParen, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ParameterList::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

//parameterDeclaration
//    : declarationSpecifiers (declarator | abstractDeclarator)?
//    ;

///|
pub struct ParameterDecl {
  decl_specs : Array[DeclSpec]
  declarator : ParamDeclarator?
} derive(Show, Eq)

///|
fn ParameterDecl::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ParameterDecl, ArrayView[Token]) raise {
  let (decl_specs, rest_toks) = DeclSpecList::parse(toks, ctx)
  let decl_specs = decl_specs.0
  guard decl_specs.length() > 0 else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (
        idx, "Parse Error: Parameter declaration must have at least one declaration specifier",
      ),
    )
  }
  //let (declarator, rest_toks) = match
  //  (try? ParamDeclarator::parse(rest_toks, ctx)) {
  //  Ok((declarator, rest_toks)) => (Some(declarator), rest_toks)
  //  Err(_) => (None, rest_toks) // No declarator or abstract declarator
  //}
  let (declarator, rest_toks) = try
    ParamDeclarator::parse(rest_toks, ctx)
  catch {
    _ => (None, rest_toks)
  } noraise {
    (declarator, rest_toks) => (Some(declarator), rest_toks)
  }
  let param_decl = ParameterDecl::{ decl_specs, declarator }
  (param_decl, rest_toks)
}

///|
test "ParameterDecl Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "int a, ": [Comma, EOF],
    "char *b ,": [Comma, EOF],
    "const int c,": [Comma, EOF],
    "float d)": [RParen, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ParameterDecl::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

///|
pub enum ParamDeclarator {
  Declarator(Declarator)
  AbstractDeclarator(AbstractDeclarator)
} derive(Show, Eq)

///|
fn ParamDeclarator::parse(
  toks : ArrayView[Token],
  ctx : ParserContext,
) -> (ParamDeclarator, ArrayView[Token]) raise {
  if (try? Declarator::parse(toks, ctx)) is Ok((declarator, rest_toks)) &&
    rest_toks is [Comma | RParen, ..] {
    (ParamDeclarator::Declarator(declarator), rest_toks)
  } else if (try? AbstractDeclarator::parse(toks, ctx))
    is Ok((abstract_declarator, rest_toks)) &&
    rest_toks is [Comma | RParen, ..] {
    (ParamDeclarator::AbstractDeclarator(abstract_declarator), rest_toks)
  } else {
    let idx = ctx.alltoks.length() - toks.length()
    raise ParseError(
      (
        idx,
        "Parse Error: Expected declarator or abstract declarator in parameter declaration, current token is \{toks[0]}",
      ),
    )
  }
}

///|
test "ParamDeclarator Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "a,": [Comma, EOF],
    "*b,": [Comma, EOF],
    "(*)(int, int),": [Comma, EOF],
    "[*],": [Comma, EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = ParserContext::create_by_code(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ParamDeclarator::parse(toks, ctx)
    assert_eq(rest_toks, expect_rest)
  }
}

// --------------------

///|
pub fn ParserContext::parse(self : Self) -> Unit raise {
  guard self.alltoks.length() > 0 else {
    println("Should do `tokenize` before parsing")
    panic()
  }
  let compilation_unit = CompilationUnit::parse(self.alltoks, self)
  for e in compilation_unit.externalDecls {
    self.external_decls.push(e)
  }
}
