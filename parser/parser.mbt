pub suberror ParseError(String) derive(Show)

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
enum PrimExpr {
  Identifier(String)
  Constant(Constant)
  StringLiteral(String)
  ParenExpr(Expr)
  //GenericSelection
} derive(Show, Eq)

fn PrimExpr::parse(toks: ArrayView[Token], ctx: Context) -> (PrimExpr, ArrayView[Token]) raise {
  match toks {
    [Identifier(name), .. rest_toks] => {
      (PrimExpr::Identifier(name), rest_toks)
    }
    [Constant(constant), .. rest_toks] => {
      (PrimExpr::Constant(constant), rest_toks)
    }
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
    [LParen, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx);
      guard rest is [RParen, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis after expression")
      }
      (PrimExpr::ParenExpr(expr), rest_toks)
    }
    curr_toks => {
      raise ParseError("Parse PrimExpr failed, current token: \{curr_toks[0]}")
    }
  }
}

test "PrimExpr Parsing Test" {
  let code_expect_rest : Map[String, (PrimExpr, ArrayView[Token])] = {
    "abc + " : (PrimExpr::Identifier("abc"), [Plus, EOF]),
    "123 - " : (PrimExpr::Constant(Constant::Int(123)), [Minus, EOF]),
    "\"hello \" \"world\" ": (PrimExpr::StringLiteral("hello world"), [EOF]),
  }

  for code, expect_rest in code_expect_rest {
    let (expect_prim, expect_rest_toks) = expect_rest
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (prim, rest_toks) = PrimExpr::parse(toks, ctx);
    assert_eq(prim, expect_prim)
    assert_eq(rest_toks, expect_rest_toks)
  }

  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "(abc + 123) - 456" : [Minus, Constant(Constant::Int(456)), EOF],
    "(a + b) * c" : [Star, Identifier("c"), EOF],
  }
  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = PrimExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
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
struct PostFixExpr {
  prim: PrimExpr
  suffixes: Array[PostFixSuffix]
} derive(Show, Eq)

fn PostFixExpr::parse(toks: ArrayView[Token], ctx: Context) -> (PostFixExpr, ArrayView[Token]) raise {
  let (prim, rest_toks) = PrimExpr::parse(toks, ctx);
  let (suffixes, rest_toks) = PostFixSuffix::parse(rest_toks, ctx);
  let post_fix_expr = PostFixExpr::{
    prim,
    suffixes
  }
  (post_fix_expr, rest_toks)
}

enum PostFixSuffix {
  Indexing(Expr)
  Call(Array[AssignExpr])
  DotAccess(String)
  ArrowAccess(String)
  PlusPlus
  MinusMinus
} derive(Show, Eq)

fn PostFixSuffix::parse(toks: ArrayView[Token], ctx: Context) -> (Array[PostFixSuffix], ArrayView[Token]) raise {
  let suffixes: Array[PostFixSuffix] = Array::new()
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
    [Arrow, Identifier(name), .. rest_toks] => {
      suffixes.push(PostFixSuffix::ArrowAccess(name))
      continue rest_toks
    }
    [LBracket, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx);
      guard rest is [RBracket, .. rest_toks] else {
        raise ParseError("Expected closing bracket after expression")
      }
      suffixes.push(PostFixSuffix::Indexing(expr))
      continue rest_toks
    }
    [LParen, .. rest_toks] => {
      let args: Array[AssignExpr] = Array::new()
      let rest_toks = loop rest_toks {
        [RParen, .. rest_toks] => break rest_toks
        [Comma, .. rest_toks] => continue rest_toks
        rest_toks => {
          let (arg, rest) = AssignExpr::parse(rest_toks, ctx);
          args.push(arg)
          continue rest
        }
      }
      suffixes.push(PostFixSuffix::Call(args))
      continue rest_toks
    }
    toks => {
      break toks // No more postfix suffixes
    }
  }
  (suffixes, rest_toks)
}

test "PostfixExpr Parsing Test" {
  let code_expect_rest : Map[String, ArrayView[Token]] = {
    "abc++ + b" : [Plus, Identifier("b"), EOF],
    "abc-- + b" : [Plus, Identifier("b"), EOF],
    "point.x * 9" : [Star, Constant(Constant::Int(9)), EOF],
    "p->x / 3" : [Slash, Constant(Constant::Int(3)), EOF],
    "fact(42) * 7" : [Star, Constant(Constant::Int(7)), EOF],
    "printf(\"The number is %d\", 42);" : [Semi, EOF],
    "mat[0][i]++;": [Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = PostFixExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//unaryExpression
//    : ('++' | '--' | 'sizeof')* (
//        postfixExpression
//        | unaryOperator castExpression
//        | ('sizeof' | '_Alignof') '(' typeName ')'
//        | '&&' Identifier // GCC extension address of label
//    )
//    ;
struct UnaryExpr {
  prifix: Array[UnaryPrefix]
  body: UnaryExprBody
} derive(Show, Eq)

fn UnaryExpr::parse(toks: ArrayView[Token], ctx: Context) -> (UnaryExpr, ArrayView[Token]) raise {
  let (prefixes, rest_toks) = UnaryPrefix::parse(toks, ctx);
  let (body, rest_toks) = UnaryExprBody::parse(rest_toks, ctx);
  let unary_expr = UnaryExpr::{
    prifix: prefixes,
    body
  }
  (unary_expr, rest_toks)
}

enum UnaryPrefix {
  PlusPlus
  MinusMinus
  Sizeof
} derive(Show, Eq)

fn UnaryPrefix::parse(toks: ArrayView[Token], ctx: Context) -> (Array[UnaryPrefix], ArrayView[Token]) {
  let prefixes: Array[UnaryPrefix] = Array::new()
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
    [Sizeof, LParen, .. rest_toks] as toks => {
      match (try? TypeName::parse(rest_toks, ctx)) {
        Err(_) => {
          prefixes.push(UnaryPrefix::Sizeof)
          continue toks[1:]
        }
        Ok(_) => break toks
      }
    }
    [Sizeof, .. rest_toks] => {
      prefixes.push(UnaryPrefix::Sizeof)
      continue rest_toks
    }
    toks => break toks // No more unary prefixes
  }
  (prefixes, rest_toks)
}

enum UnaryOperator {
  AddressOf  // &
  Dereference // *
  Positive    // +
  Negative    // -
  LogicalNot  // !
  BitwiseNot  // ~
} derive(Show, Eq)

fn UnaryOperator::parse(toks: ArrayView[Token]) -> (UnaryOperator, ArrayView[Token]) raise {
  match toks {
    [And, .. rest_toks] => (AddressOf, rest_toks)
    [Star, .. rest_toks] => (Dereference, rest_toks)
    [Plus, .. rest_toks] => (Positive, rest_toks)
    [Minus, .. rest_toks] => (Negative, rest_toks)
    [Not, .. rest_toks] => (LogicalNot, rest_toks)
    [Tilde, .. rest_toks] => (BitwiseNot, rest_toks)
    _ => raise ParseError("Expected unary operator")
  }
}

enum UnaryExprBody {
  PostFix(PostFixExpr)
  UnaryOp(UnaryOperator, CastExpr)
  SizeofTypeName(TypeName)
  AlignOfTypeName(TypeName)
} derive(Show, Eq)

fn UnaryExprBody::parse(toks: ArrayView[Token], ctx: Context) -> (UnaryExprBody, ArrayView[Token]) raise {
  match toks {
    [And | Star | Plus | Minus | Not | Tilde as sym, .. rest_toks] => {
      let (cast_expr, rest_toks) = CastExpr::parse(rest_toks, ctx);
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
      let (type_name, rest_toks) = TypeName::parse(rest_toks, ctx);
      guard rest_toks is [RParen, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis after type name in sizeof")
      }
      (UnaryExprBody::SizeofTypeName(type_name), rest_toks)
    }
    [Alignof, LParen, .. rest_toks] => {
      let (type_name, rest_toks) = TypeName::parse(rest_toks, ctx);
      guard rest_toks is [RParen, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis after type name in _Alignof")
      }
      (UnaryExprBody::AlignOfTypeName(type_name), rest_toks)
    }
    toks => {
      let (post_fix_expr, rest_toks) = PostFixExpr::parse(toks, ctx);
      (UnaryExprBody::PostFix(post_fix_expr), rest_toks)
    }
  }
}

test "UnaryExpr Parsing Test" {

  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "++abc + b" : [Plus, Identifier("b"), EOF],
    "--abc + b" : [Plus, Identifier("b"), EOF],
    "sizeof(int) + 1" : [Plus, Constant(Constant::Int(1)), EOF],
    "_Alignof(int) + 2" : [Plus, Constant(Constant::Int(2)), EOF],
    "&abc + b" : [Plus, Identifier("b"), EOF],
    "*abc + b" : [Plus, Identifier("b"), EOF],
    "+abc + b" : [Plus, Identifier("b"), EOF],
    "-abc + b" : [Plus, Identifier("b"), EOF],
    "!abc + b" : [Plus, Identifier("b"), EOF],
    "~abc + b" : [Plus, Identifier("b"), EOF],
    "++mat[i][j];" : [Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = UnaryExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//castExpression
//    : '__extension__'? '(' typeName ')' castExpression
//    | unaryExpression
//    | DigitSequence // for
//    ;
type CastExpr (Array[TypeName], UnaryExpr) derive(Show, Eq)

fn CastExpr::parse(toks: ArrayView[Token], ctx: Context) -> (CastExpr, ArrayView[Token]) raise {
  let cast_types: Array[TypeName] = Array::new()
  loop toks {
    [LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx);
      guard rest is [RParen, .. rest] else {
        raise ParseError("Expected closing parenthesis after type name in cast")
      }
      cast_types.push(type_name)
      continue rest
    }
    toks => {
      let (unary_expr, rest_toks) = UnaryExpr::parse(toks, ctx);
      (CastExpr((cast_types, unary_expr)), rest_toks)
    }
  }
}

test "CastExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "(int)abc + b" : [Plus, Identifier("b"), EOF],
    "(int)(float)abc + b" : [Plus, Identifier("b"), EOF],
    "(int)123 + b" : [Plus, Identifier("b"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = CastExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//multiplicativeExpression
//    : castExpression (('*' | '/' | '%') castExpression)*
//    ;
struct MultExpr {
  exprs: Array[CastExpr]
  ops: Array[MultOp]
} derive(Show, Eq)

enum MultOp {
  Mult // *
  Div // /
  Mod // %
} derive(Show, Eq)

fn MultExpr::parse(toks: ArrayView[Token], ctx: Context) -> (MultExpr, ArrayView[Token]) raise {
  let exprs: Array[CastExpr] = Array::new()
  let ops: Array[MultOp] = Array::new()
  let (first_expr, rest_toks) = CastExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Star, .. rest_toks] => {
      ops.push(MultOp::Mult)
      let (next_expr, rest) = CastExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [Slash, .. rest_toks] => {
      ops.push(MultOp::Div)
      let (next_expr, rest) = CastExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [Mod, .. rest_toks] => {
      ops.push(MultOp::Mod)
      let (next_expr, rest) = CastExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let mult_expr = MultExpr::{ exprs, ops }
  (mult_expr, rest_toks)
}

test "MultExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "abc * b + bbcc" : [Plus, Identifier("bbcc"), EOF],
    "abc / b + a123" : [Plus, Identifier("a123"), EOF],
    "abc % b - u89" : [Minus, Identifier("u89"), EOF],
    "123 * 456 + 789" : [Plus, Constant(Constant::Int(789)), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = MultExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//additiveExpression
//    : multiplicativeExpression (('+' | '-') multiplicativeExpression)*
//    ;
struct AddSubExpr {
  exprs: Array[MultExpr]
  ops: Array[AddSubOp]
} derive(Show, Eq)

enum AddSubOp {
  Add // +
  Sub // -
} derive(Show, Eq)

fn AddSubExpr::parse(toks: ArrayView[Token], ctx: Context) -> (AddSubExpr, ArrayView[Token]) raise {
  let exprs: Array[MultExpr] = Array::new()
  let ops: Array[AddSubOp] = Array::new()
  let (first_expr, rest_toks) = MultExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Plus, .. rest_toks] => {
      ops.push(AddSubOp::Add)
      let (next_expr, rest) = MultExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [Minus, .. rest_toks] => {
      ops.push(AddSubOp::Sub)
      let (next_expr, rest) = MultExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let add_sub_expr = AddSubExpr::{ exprs, ops }
  (add_sub_expr, rest_toks)
}

test "AddSubExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "abc + b - c > 78" : [GT, Constant(Constant::Int(78)), EOF],
    "abc - b + d <= 96" : [LE, Constant(Constant::Int(96)), EOF],
    "123 + 456 - 789 == 12345" : [EQ, Constant(Constant::Int(12345)), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AddSubExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//shiftExpression
//    : additiveExpression (('<<' | '>>') additiveExpression)*
//    ;
struct ShiftExpr {
  exprs: Array[AddSubExpr]
  ops: Array[ShiftOp]
} derive(Show, Eq)

enum ShiftOp {
  Shl // <<
  Shr // >>
} derive(Show, Eq)

fn ShiftExpr::parse(toks: ArrayView[Token], ctx: Context) -> (ShiftExpr, ArrayView[Token]) raise {
  let exprs: Array[AddSubExpr] = Array::new()
  let ops: Array[ShiftOp] = Array::new()
  let (first_expr, rest_toks) = AddSubExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Shl, .. rest_toks] => {
      ops.push(ShiftOp::Shl)
      let (next_expr, rest) = AddSubExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [Shr, .. rest_toks] => {
      ops.push(ShiftOp::Shr)
      let (next_expr, rest) = AddSubExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let shift_expr = ShiftExpr::{ exprs, ops }
  (shift_expr, rest_toks)
}

test "ShiftExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a << 1 > 345 " : [GT, Constant(Constant::Int(345)), EOF],
    "b >> 2 < 456" : [LT, Constant(Constant::Int(456)), EOF],
    "c << 3 == 789" : [EQ, Constant(Constant::Int(789)), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ShiftExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//relationalExpression
//    : shiftExpression (('<' | '>' | '<=' | '>=') shiftExpression)*
//    ;
struct RelationalExpr {
  exprs: Array[ShiftExpr]
  ops: Array[RelationalOp]
} derive(Show, Eq)

enum RelationalOp {
  LT // <
  GT // >
  LE // <=
  GE // >=
} derive(Show, Eq)

fn RelationalExpr::parse(toks: ArrayView[Token], ctx: Context) -> (RelationalExpr, ArrayView[Token]) raise {
  let exprs: Array[ShiftExpr] = Array::new()
  let ops: Array[RelationalOp] = Array::new()
  let (first_expr, rest_toks) = ShiftExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [LT, .. rest_toks] => {
      ops.push(RelationalOp::LT)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [GT, .. rest_toks] => {
      ops.push(RelationalOp::GT)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [LE, .. rest_toks] => {
      ops.push(RelationalOp::LE)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [GE, .. rest_toks] => {
      ops.push(RelationalOp::GE)
      let (next_expr, rest) = ShiftExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let relational_expr = RelationalExpr::{ exprs, ops }
  (relational_expr, rest_toks)
}

test "RelationalExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a < b + c && True" : [DoubleAnd, Identifier("True"), EOF],
    "d > e - f || False" : [DoubleOr, Identifier("False"), EOF],
    "g <= h * i && cond" : [DoubleAnd, Identifier("cond"), EOF],
    "j >= k / l || cond" : [DoubleOr, Identifier("cond"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = RelationalExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//equalityExpression
//    : relationalExpression (('==' | '!=') relationalExpression)*
//    ;
struct EqualityExpr {
  exprs: Array[RelationalExpr]
  ops: Array[EqualityOp]
} derive(Show, Eq)

enum EqualityOp {
  EQ // ==
  NE // !=
} derive(Show, Eq)

fn EqualityExpr::parse(toks: ArrayView[Token], ctx: Context) -> (EqualityExpr, ArrayView[Token]) raise {
  let exprs: Array[RelationalExpr] = Array::new()
  let ops: Array[EqualityOp] = Array::new()
  let (first_expr, rest_toks) = RelationalExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [EQ, .. rest_toks] => {
      ops.push(EqualityOp::EQ)
      let (next_expr, rest) = RelationalExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    [NE, .. rest_toks] => {
      ops.push(EqualityOp::NE)
      let (next_expr, rest) = RelationalExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let equality_expr = EqualityExpr::{ exprs, ops }
  (equality_expr, rest_toks)
}

test "EqualityExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a == b + c || True" : [DoubleOr, Identifier("True"), EOF],
    "d != e - f && False" : [DoubleAnd, Identifier("False"), EOF],
    "g == h * i || cond" : [DoubleOr, Identifier("cond"), EOF],
    "j != k / l && cond" : [DoubleAnd, Identifier("cond"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = EqualityExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//andExpression
//    : equalityExpression ('&' equalityExpression)*
//    ;
struct AndExpr {
  exprs: Array[EqualityExpr]
} derive(Show, Eq)

fn AndExpr::parse(toks: ArrayView[Token], ctx: Context) -> (AndExpr, ArrayView[Token]) raise {
  let exprs: Array[EqualityExpr] = Array::new()
  let (first_expr, rest_toks) = EqualityExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [And, .. rest_toks] => {
      let (next_expr, rest) = EqualityExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let and_expr = AndExpr::{ exprs }
  (and_expr, rest_toks)
}

test "AndExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a & b | c " : [Or, Identifier("c"), EOF],
    "a & c ^ d" : [Xor, Identifier("d"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AndExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//exclusiveOrExpression
//    : andExpression ('^' andExpression)*
//    ;
struct ExclusiveOrExpr {
  exprs: Array[AndExpr]
} derive(Show, Eq)

fn ExclusiveOrExpr::parse(toks: ArrayView[Token], ctx: Context) -> (ExclusiveOrExpr, ArrayView[Token]) raise {
  let exprs: Array[AndExpr] = Array::new()
  let (first_expr, rest_toks) = AndExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Xor, .. rest_toks] => {
      let (next_expr, rest) = AndExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let exclusive_or_expr = ExclusiveOrExpr::{ exprs }
  (exclusive_or_expr, rest_toks)
}

test "ExclusiveOrExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "1 & a ^ b ? c" : [Question, Identifier("c"), EOF],
    "d ^ e & 1 ? f" : [Question, Identifier("f"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ExclusiveOrExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//inclusiveOrExpression
//    : exclusiveOrExpression ('|' exclusiveOrExpression)*
//    ;
struct InclusiveOrExpr {
  exprs: Array[ExclusiveOrExpr]
} derive(Show, Eq)

fn InclusiveOrExpr::parse(toks: ArrayView[Token], ctx: Context) -> (InclusiveOrExpr, ArrayView[Token]) raise {
  let exprs: Array[ExclusiveOrExpr] = Array::new()
  let (first_expr, rest_toks) = ExclusiveOrExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Or, .. rest_toks] => {
      let (next_expr, rest) = ExclusiveOrExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let inclusive_or_expr = InclusiveOrExpr::{ exprs }
  (inclusive_or_expr, rest_toks)
}

test "InclusiveOrExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a | b ? c" : [Question, Identifier("c"), EOF],
    "d | e ? f" : [Question, Identifier("f"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    //let toks = lex(code)
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = InclusiveOrExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//logicalAndExpression
//    : inclusiveOrExpression ('&&' inclusiveOrExpression)*
//    ;
struct LogicalAndExpr {
  exprs: Array[InclusiveOrExpr]
} derive(Show, Eq)

fn LogicalAndExpr::parse(toks: ArrayView[Token], ctx: Context) -> (LogicalAndExpr, ArrayView[Token]) raise {
  let exprs: Array[InclusiveOrExpr] = Array::new()
  let (first_expr, rest_toks) = InclusiveOrExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [DoubleAnd, .. rest_toks] => {
      let (next_expr, rest) = InclusiveOrExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let logical_and_expr = LogicalAndExpr::{ exprs }
  (logical_and_expr, rest_toks)
}

test "LogicalAndExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a && b || c" : [DoubleOr, Identifier("c"), EOF],
    "d && e || f" : [DoubleOr, Identifier("f"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = LogicalAndExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//logicalOrExpression
//    : logicalAndExpression ('||' logicalAndExpression)*
//    ;
struct LogicalOrExpr {
  exprs: Array[LogicalAndExpr]
} derive(Show, Eq)

fn LogicalOrExpr::parse(toks: ArrayView[Token], ctx: Context) -> (LogicalOrExpr, ArrayView[Token]) raise {
  let exprs: Array[LogicalAndExpr] = Array::new()
  let (first_expr, rest_toks) = LogicalAndExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [DoubleOr, .. rest_toks] => {
      let (next_expr, rest) = LogicalAndExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let logical_or_expr = LogicalOrExpr::{ exprs }
  (logical_or_expr, rest_toks)
}

test "LogicalOrExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a || b ? c" : [Question, Identifier("c"), EOF],
    "d || e ? f" : [Question, Identifier("f"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = LogicalOrExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//conditionalExpression
//    : logicalOrExpression ('?' expression ':' conditionalExpression)?
//    ;
struct ConditionalExpr {
  expr: LogicalOrExpr
  select: (Expr, ConditionalExpr)?
} derive(Show, Eq)

fn ConditionalExpr::parse(toks: ArrayView[Token], ctx: Context) -> (ConditionalExpr, ArrayView[Token]) raise {
  let (logical_or_expr, rest_toks) = LogicalOrExpr::parse(toks, ctx);
  match  rest_toks {
    [Question, .. rest_toks] => {
      let (expr, rest) = Expr::parse(rest_toks, ctx);
      guard rest is [Colon, .. rest_toks] else {
        raise ParseError("Expected ':' after expression in conditional expression")
      }
      let (conditional_expr, rest_toks) = ConditionalExpr::parse(rest_toks, ctx);
      let conditional_expr = ConditionalExpr::{
        expr: logical_or_expr,
        select: Some((expr, conditional_expr))
      }
      (conditional_expr, rest_toks)
    }
    _ => {
      let conditional_expr = ConditionalExpr::{
        expr: logical_or_expr,
        select: None
      }
      (conditional_expr, rest_toks)
    }
  }
}

test "ConditionalExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "cond1 ? 123 : 456 ; int" : [Semi, Int, EOF],
    "cond1 && cond2 ? abc : def ; struct" : [Semi, Struct, EOF],
    "init || Next ? 7 : 8; " : [Semi, EOF],
    "a123 += 5" : [PlusAssign, Constant(Constant::Int(5)), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ConditionalExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}


//assignmentExpression
//    : conditionalExpression
//    | unaryExpression assignmentOperator assignmentExpression
//    | DigitSequence // for
//    ;
enum AssignExpr {
  Conditional(ConditionalExpr)
  Assign(UnaryExpr, AssignOp, AssignExpr)
} derive(Show, Eq)

fn AssignExpr::parse(toks: ArrayView[Token], ctx:Context) -> (AssignExpr, ArrayView[Token]) raise {
  let (unary_expr, rest_toks) = UnaryExpr::parse(toks, ctx);
  match rest_toks {
    [Assign | PlusAssign | MinusAssign | StarAssign | DivAssign | ModAssign |
     LeftShiftAssign | RightShiftAssign | AndAssign | BitXorAssign |
     BitOrAssign as op, .. rest_toks] => {
      let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx);
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
      let (cond_expr, rest_toks) = ConditionalExpr::parse(toks, ctx);
      (AssignExpr::Conditional(cond_expr), rest_toks)
    }
  }
}

test "AssignExpr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a = b + c; int" : [Semi, Int, EOF],
    "x += 5; union" : [Semi, Union, EOF],
    "cond1 && cond2 ? abc : def ; struct" : [Semi, Struct, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = AssignExpr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

enum AssignOp {
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
struct Expr {
  exprs: Array[AssignExpr]
} derive(Show, Eq)

fn Expr::parse(toks: ArrayView[Token], ctx: Context) -> (Expr, ArrayView[Token]) raise {
  let exprs: Array[AssignExpr] = Array::new()
  let (first_expr, rest_toks) = AssignExpr::parse(toks, ctx);
  exprs.push(first_expr)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_expr, rest) = AssignExpr::parse(rest_toks, ctx);
      exprs.push(next_expr)
      continue rest
    }
    toks => break toks
  }
  let expr = Expr::{ exprs }
  (expr, rest_toks)
}

test "Expr Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a = b + c, d = e - f; int" : [Semi, Int, EOF],
    "x += 5, y -= 10; union" : [Semi, Union, EOF],
    "cond1 && cond2 ? abc : def ; struct" : [Semi, Struct, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Expr::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

typealias ConditionalExpr as ConstantExpr

//declaration
//    : declarationSpecifiers initDeclaratorList? ';'
//    | staticAssertDeclaration
//    ;
enum Declaration {
  Decl(Array[DeclSpec], Array[InitDeclarator])
  //StaticAssertDecl(StaticAssertDecl)
} derive(Show, Eq)

fn Declaration::parse(toks: ArrayView[Token], ctx: Context) -> (Declaration, ArrayView[Token]) raise {
  println("Declaration::parse unimplemented")
  panic()
  ...
}

enum DeclSpec {
  StorageClassSpec(StorageClassSpec)
  TypeSpec(TypeSpec)
  TypeQualifier(TypeQualifier)
  FunctionSpec(FunctionSpec)
  AlignmentSpec(AlignmentSpec)
} derive(Show, Eq)

fn DeclSpec::parse(toks: ArrayView[Token], ctx: Context) -> (DeclSpec, ArrayView[Token]) raise {
  match toks {
    [Auto | Register | Static | ThreadLocal | Extern | Typedef, ..] => {
      let (storage_class_spec, rest_toks) = StorageClassSpec::parse(toks);
      (DeclSpec::StorageClassSpec(storage_class_spec), rest_toks)
    }
    [Const | Volatile | Restrict | Atomic, ..] => {
      let (type_qualifier, rest_toks) = TypeQualifier::parse(toks);
      (DeclSpec::TypeQualifier(type_qualifier), rest_toks)
    }
    [Inline, Noreturn, ..] => {
      let (function_spec, rest_toks) = FunctionSpec::parse(toks);
      (DeclSpec::FunctionSpec(function_spec), rest_toks)
    }
    [Alignas, ..] => {
      let (alignment_spec, rest_toks) = AlignmentSpec::parse(toks, ctx);
      (DeclSpec::AlignmentSpec(alignment_spec), rest_toks)
    }
    _ => {
      let (type_spec, rest_toks) = TypeSpec::parse(toks, ctx);
      (DeclSpec::TypeSpec(type_spec), rest_toks)
    }
  }
}

type DeclSpecList Array[DeclSpec] derive(Show, Eq)

fn DeclSpecList::parse(toks: ArrayView[Token], ctx: Context) -> (DeclSpecList, ArrayView[Token]) {
  let decl_specs: Array[DeclSpec] = Array::new()
  let mut rest_toks = toks
  while (try? DeclSpec::parse(rest_toks, ctx)) is Ok((decl_spec, rest)) {
    decl_specs.push(decl_spec)
    rest_toks = rest
    // If we encounter a TypeSpec, we can stop parsing further decl specs
    if decl_spec is TypeSpec(_) {
      break
    }
  }
  (DeclSpecList(decl_specs), rest_toks)
}

test "DeclSpecList Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "int a;" : [Identifier("a"), Semi, EOF],
    "const char *p;" : [Star, Identifier("p"), Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DeclSpecList::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

enum StorageClassSpec {
  Auto // auto
  Register // register
  Static // static
  ThreadLocal // _Thread_local
  Extern // extern
  Typedef // typedef
} derive(Show, Eq)

fn StorageClassSpec::parse(toks: ArrayView[Token]) -> (StorageClassSpec, ArrayView[Token]) raise {
  match toks {
    [Auto, .. rest_toks] => (StorageClassSpec::Auto, rest_toks)
    [Register, .. rest_toks] => (StorageClassSpec::Register, rest_toks)
    [Static, .. rest_toks] => (StorageClassSpec::Static, rest_toks)
    [ThreadLocal, .. rest_toks] => (StorageClassSpec::ThreadLocal, rest_toks)
    [Extern, .. rest_toks] => (StorageClassSpec::Extern, rest_toks)
    [Typedef, .. rest_toks] => (StorageClassSpec::Typedef, rest_toks)
    _ => raise ParseError("Unimplemented storage class specifier")
  }
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
enum TypeSpec {
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

fn TypeSpec::parse(toks: ArrayView[Token], ctx: Context) -> (TypeSpec, ArrayView[Token]) raise {
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
      let (type_name, rest) = TypeName::parse(rest_toks, ctx);
      guard rest is [RParen, .. rest] else {
        raise ParseError("Expected closing parenthesis after type name in _Atomic")
      }
      (TypeSpec::Atomic(type_name), rest)
    }
    [Struct, .. ] as toks => {
      let (struct_spec, rest_toks) = StructSpec::parse(toks, ctx);
      (TypeSpec::StructSpec(struct_spec), rest_toks)
    }
    [Union, .. ] as toks => {
      let (union_spec, rest_toks) = UnionSpec::parse(toks, ctx);
      (TypeSpec::UnionSpec(union_spec), rest_toks)
    }
    [Enum, ..] as toks => {
      let (enum_spec, rest_toks) = EnumSpec::parse(toks);
      (TypeSpec::EnumSpec(enum_spec), rest_toks)
    }
    [Identifier(name), .. rest_toks] if ctx.typedefs.get(name) is Some(_) => (TypeSpec::TypedefName(name), rest_toks)
    toks => raise ParseError("Parse TypeSpec Error, unexpect token \{toks[0]}")
  }
}

enum TypeQualifier {
  Const // const
  Volatile // volatile
  Restrict // restrict
  Atomic // _Atomic
} derive(Show, Eq)

fn TypeQualifier::parse(toks: ArrayView[Token]) -> (TypeQualifier, ArrayView[Token]) raise {
  match toks {
    [Const, .. rest_toks] => (TypeQualifier::Const, rest_toks)
    [Volatile, .. rest_toks] => (TypeQualifier::Volatile, rest_toks)
    [Restrict, .. rest_toks] => (TypeQualifier::Restrict, rest_toks)
    [Atomic, .. rest_toks] => (TypeQualifier::Atomic, rest_toks)
    _ => raise ParseError("Unimplemented type qualifier")
  }
}

type TypeQualifierList Array[TypeQualifier] derive(Show, Eq)

fn TypeQualifierList::parse(toks: ArrayView[Token]) -> (TypeQualifierList, ArrayView[Token]) {
  let qualifiers: Array[TypeQualifier] = Array::new()
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

fn TypeQualifierList::is_empty(self: Self) -> Bool {
  self.inner().is_empty()
}

enum TypeSpecOrQualifier {
  TypeSpec(TypeSpec)
  TypeQualifier(TypeQualifier)
} derive(Show, Eq)

fn TypeSpecOrQualifier::parse(toks: ArrayView[Token], ctx: Context) -> (TypeSpecOrQualifier, ArrayView[Token]) raise {
  match toks {
    [Const, .. rest_toks] => (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Const), rest_toks)
    [Volatile, .. rest_toks] => (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Volatile), rest_toks)
    [Restrict, .. rest_toks] => (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Restrict), rest_toks)
    [Atomic, .. rest_toks] => (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Atomic), rest_toks)
    _ => {
      let (type_spec, rest) = TypeSpec::parse(toks, ctx);
      (TypeSpecOrQualifier::TypeSpec(type_spec), rest)
    }
  }
}

type TypeSpecOrQualifierList Array[TypeSpecOrQualifier] derive(Show, Eq)

fn TypeSpecOrQualifierList::parse(toks: ArrayView[Token], ctx: Context) -> (TypeSpecOrQualifierList, ArrayView[Token]) {
  let specs: Array[TypeSpecOrQualifier] = Array::new()
  let mut toks = toks
  while (try? TypeSpecOrQualifier::parse(toks, ctx)) is Ok((spec, rest)) {
    specs.push(spec)
    toks = rest
    // If we encounter a TypeSpec, we can stop parsing further type specifiers
    if spec is TypeSpec(_) {
      break
    }
  }
  (TypeSpecOrQualifierList(specs), toks)
}

struct StructSpec {
  name: String?
  decls: Array[StructDeclaration]
} derive(Show, Eq)

fn StructSpec::parse(toks: ArrayView[Token], ctx: Context) -> (StructSpec, ArrayView[Token]) raise {
  guard toks is [Struct, .. toks] else {
    raise ParseError("Expected 'struct' keyword for struct specification")
  }

  let (name, rest_toks) = match toks {
    [Identifier(name), LBrace, .. rest_toks] => (Some(name), rest_toks)
    [LBrace, .. rest_toks] => (None, rest_toks) // No name specified
    _ => raise ParseError("Expected identifier or '{' after 'struct'")
  }

  let decls : Array[StructDeclaration] = Array::new()

  let rest_toks = loop rest_toks {
    [RBrace, ..rest_toks] => {
      break rest_toks
    }
    [Semi, .. rest_toks] => {
      // Empty declaration, just skip it
      continue rest_toks
    }
    rest_toks => {
      let (struct_decl, rest_toks) = StructDeclaration::parse(rest_toks, ctx);
      decls.push(struct_decl);
      continue rest_toks
    }
  }
  let struct_spec = StructSpec::{ name, decls };
  (struct_spec, rest_toks)
}

test "StructSpec Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "struct MyStruct { int a; double b; }" : [EOF],
    "struct { char c; }" : [EOF],
    "struct EmptyStruct {}" : [EOF],
    "struct AnotherStruct { int x; }" : [EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StructSpec::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

struct UnionSpec {
  name: String?
  decls: Array[StructDeclaration]
} derive(Show, Eq)

fn UnionSpec::parse(toks: ArrayView[Token], ctx: Context) -> (UnionSpec, ArrayView[Token]) raise {
  guard toks is [Union, .. toks] else {
    raise ParseError("Expected 'struct' keyword for struct specification")
  }

  let (name, rest_toks) = match toks {
    [Identifier(name), LBrace, .. rest_toks] => (Some(name), rest_toks)
    [LBrace, .. rest_toks] => (None, rest_toks) // No name specified
    _ => raise ParseError("Expected identifier or '{' after 'struct'")
  }

  let decls : Array[StructDeclaration] = Array::new()

  let rest_toks = loop rest_toks {
    [RBrace, ..rest_toks] => {
      break rest_toks
    }
    [Semi, .. rest_toks] => {
      // Empty declaration, just skip it
      continue rest_toks
    }
    rest_toks => {
      let (struct_decl, rest_toks) = StructDeclaration::parse(rest_toks, ctx);
      decls.push(struct_decl);
      continue rest_toks
    }
  }
  let union_spec = UnionSpec::{ name, decls };
  (union_spec, rest_toks)
}

test "UnionSpec Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "union MyUnion { int a; double b; }" : [EOF],
    "union { char c; }" : [EOF],
    "union EmptyUnion {}" : [EOF],
    "union AnotherUnion { int x; }" : [EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = UnionSpec::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//structDeclaration // The first two rules have priority order and cannot be simplified to one expression.
//    : specifierQualifierList structDeclaratorList ';'
//    | specifierQualifierList ';'
//    | staticAssertDeclaration
//    ;
enum StructDeclaration {
  Normal(Array[TypeSpecOrQualifier], Array[StructDeclarator])
  //StaticAssertDecl(StaticAssertDecl)
} derive(Show, Eq)

fn StructDeclaration::parse(toks: ArrayView[Token], ctx: Context) -> (StructDeclaration, ArrayView[Token]) raise {
  let (type_spec_or_qualifiers, rest_toks) = TypeSpecOrQualifierList::parse(toks, ctx);
  let type_spec_or_qualifiers = type_spec_or_qualifiers.inner()

  if rest_toks is [Semi, .. rest_toks] {
    // Case: specifierQualifierList ';'
    return (StructDeclaration::Normal(type_spec_or_qualifiers, Array::new()), rest_toks)
  }

  let (struct_declarators, rest_toks) = StructDeclaratorList::parse(rest_toks, ctx);
  (StructDeclaration::Normal(type_spec_or_qualifiers, struct_declarators.inner()), rest_toks)
}

test "StructDeclaration Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "int a, b;" : [Semi, EOF],
    "double x;" : [Semi, EOF],
    "int a : 1, b : 2;" : [Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StructDeclaration::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

enum StructOrUnionKind {
  Struct // struct
  Union // union
} derive(Show, Eq)

enum StructDeclarator {
  Declarator(Declarator)
  Field(Declarator?, ConstantExpr)
} derive(Show, Eq)

//structDeclarator
//    : declarator
//    | declarator? ':' constantExpression
//    ;
fn StructDeclarator::parse(toks: ArrayView[Token], ctx: Context) -> (StructDeclarator, ArrayView[Token]) raise {
  if toks is [Colon, ..rest_toks] {
    let (const_expr, rest_toks) = ConstantExpr::parse(rest_toks, ctx);
    return (StructDeclarator::Field(None, const_expr), rest_toks)
  }

  let (declarator, rest_toks) = Declarator::parse(toks, ctx);
  match rest_toks {
    [Colon, .. rest_toks] => {
      let (const_expr, rest_toks) = ConstantExpr::parse(rest_toks, ctx);
      (StructDeclarator::Field(Some(declarator), const_expr), rest_toks)
    }
    _ => (StructDeclarator::Declarator(declarator), rest_toks)
  }
}

type StructDeclaratorList Array[StructDeclarator] derive(Show, Eq)

fn StructDeclaratorList::parse(toks: ArrayView[Token], ctx: Context) -> (StructDeclaratorList, ArrayView[Token]) raise {
  let decls: Array[StructDeclarator] = Array::new()
  let (first_decl, rest_toks) = StructDeclarator::parse(toks, ctx);
  decls.push(first_decl)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_decl, rest) = StructDeclarator::parse(rest_toks, ctx);
      decls.push(next_decl)
      continue rest
    }
    toks => break toks // no more struct declarators
  }
  (StructDeclaratorList(decls), rest_toks)
}

test "StructDeclaratorList Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a ;" : [Semi, EOF],
    "a, b ;" : [Semi, EOF],
    "a : 1, b : 2 ;" : [Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = StructDeclaratorList::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

struct Declarator {
  pointer: Pointer?
  directDeclarator: DirectDeclarator
} derive(Show, Eq)

fn Declarator::parse(toks: ArrayView[Token], ctx: Context) -> (Declarator, ArrayView[Token]) raise {
  let (pointer, rest_toks) = Pointer::parse(toks);
  let pointer = if pointer.inner().is_empty() {
    None // No pointer qualifiers
  } else {
    Some(pointer)
  }
  let (direct_declarator, rest_toks) = DirectDeclarator::parse(rest_toks, ctx);
  (Declarator::{ pointer, directDeclarator: direct_declarator }, rest_toks)
}

test "Declarator Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a" : [EOF],
    "*b" : [EOF],
    "**c" : [EOF],
    "* const Point" : [EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Declarator::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//pointer
//    : (('*' | '^') typeQualifierList?)+ // ^ - Blocks language extension
//    ;
type Pointer Array[TypeQualifier?]  derive(Show, Eq)

fn Pointer::parse(toks: ArrayView[Token]) -> (Pointer, ArrayView[Token]) {
  let qualifiers: Array[TypeQualifier?] = Array::new()
  let rest_toks = loop toks {
    [Star, Const, ..rest_toks] => {
      qualifiers.push(Some(Const))
      continue rest_toks
    }
    [Star, Volatile, ..rest_toks] => {
      qualifiers.push(Some(Volatile))
      continue rest_toks
    }
    [Star, Restrict, ..rest_toks] => {
      qualifiers.push(Some(Restrict))
      continue rest_toks
    }
    [Star, Atomic, ..rest_toks] => {
      qualifiers.push(Some(Atomic))
      continue rest_toks
    }
    [Star, .. rest_toks] => {
      qualifiers.push(None) // Pointer without type qualifier
      continue rest_toks
    }
    toks => break toks // no more pointers
  }
  (Pointer(qualifiers), rest_toks)
}

test "Pointer Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "*a": [Identifier("a"), EOF],
    "**b": [Identifier("b"), EOF],
    "* const Point": [Identifier("Point"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = Pointer::parse(toks);
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
enum DirectDeclarator {
  Identifier(String)
  Parenthesized(Declarator)
  Array(DirectDeclarator, TypeQualifierList, AssignExpr?)
  StaticArray(DirectDeclarator, Array[TypeQualifier], AssignExpr)
  VallengthArray(DirectDeclarator, Array[TypeQualifier])
  FunctionDecl(DirectDeclarator, ParameterTypeList)
  FunctionPtr(DirectDeclarator, Array[String])
  BitField(String, Int)
} derive(Show, Eq)

fn DirectDeclarator::parse(toks: ArrayView[Token], ctx: Context) -> (DirectDeclarator, ArrayView[Token]) raise {
  let (head_decl, rest_toks) = match toks {
    [Identifier(name), .. rest_toks] => (DirectDeclarator::Identifier(name), rest_toks)
    [LParen, .. rest_toks] => {
      let (declarator, rest) = Declarator::parse(rest_toks, ctx);
      guard rest is [RParen, .. rest] else {
        raise ParseError("Expected closing parenthesis after declarator")
      }
      (DirectDeclarator::Parenthesized(declarator), rest)
    }
    toks => raise ParseError("Unimplemented direct declarator parsing, current token: \{toks[0]}")
  }
  let mut current_decl = head_decl
  loop rest_toks {
    [LBracket, Static, ..rest_toks] => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(rest_toks);
      let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx);
      current_decl = DirectDeclarator::StaticArray(current_decl, type_qualifiers.inner(), assign_expr)
      continue rest_toks
    }
    [LBracket, ..rest_toks] => {
      let (type_qualifiers, rest_toks) = TypeQualifierList::parse(rest_toks);
      let rest_toks = match rest_toks {
        [Static, .. rest_toks] => {
          let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx);
          current_decl = DirectDeclarator::StaticArray(current_decl, type_qualifiers.inner(), assign_expr)
          guard rest_toks is [RBracket, ..rest_toks] else {
            raise ParseError("Expected closing bracket after static array declaration")
          }
          rest_toks
        }
        [Star, .. rest_toks] => {
          current_decl = DirectDeclarator::VallengthArray(current_decl, type_qualifiers.inner())
          guard rest_toks is [RBracket, ..rest_toks] else {
            raise ParseError("Expected closing bracket after variable length array declaration")
          }
          rest_toks
        }
        [RBracket, ..rest_toks] => {
          current_decl = DirectDeclarator::Array(current_decl, type_qualifiers.inner(), None)
          rest_toks
        }
        _ => {
          let (assign_expr, rest_toks) = AssignExpr::parse(rest_toks, ctx);
          current_decl = DirectDeclarator::Array(current_decl, type_qualifiers.inner(), Some(assign_expr))
          guard rest_toks is [RBracket, ..rest_toks] else {
            raise ParseError("Expected closing bracket after array declaration")
          }
          rest_toks
        }
      }
      continue rest_toks
    }
    // IdentifierList
    [LParen, Identifier(name), Comma, ..rest_toks] => {
      let identifiers: Array[String] = [name]
      let rest_toks = loop rest_toks {
        [Identifier(next_name), ..rest_toks] => {
          identifiers.push(next_name)
          continue rest_toks
        }
        [Comma, ..rest_toks] => continue rest_toks
        [RParen, ..rest_toks] => {
          break rest_toks
        }
        _ => raise ParseError("Expected identifier or closing parenthesis in identifier list")
      }
      current_decl = DirectDeclarator::FunctionPtr(current_decl, identifiers)
      continue rest_toks
    }
    // IdentifierList
    [LParen, Identifier(name), RParen, ..rest_toks] => {
      let identifiers: Array[String] = [name]
      current_decl = DirectDeclarator::FunctionPtr(current_decl, identifiers)
      continue rest_toks
    }
    [LParen, RParen, ..rest_toks] => {
      current_decl = DirectDeclarator::FunctionPtr(current_decl, [])
      continue rest_toks
    }
    // parameterTypeList
    [LParen, ..rest_toks] => {
      let (params, rest_toks) = ParameterTypeList::parse(rest_toks, ctx);
      current_decl = DirectDeclarator::FunctionDecl(current_decl, params);
      guard rest_toks is [RParen, ..rest_toks] else {
        raise ParseError("Expected closing parenthesis after parameter type list")
      }
      continue rest_toks
    }
    // BitField
    [Identifier(name), Colon, Constant(Int(i)), ..rest_toks] => {
      current_decl = DirectDeclarator::BitField(name, i);
      continue rest_toks
    }
    rest_toks => {
      break (current_decl, rest_toks) // No more direct declarators
    }
  }
}

test "DirectDeclarator Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "arr ;" : [Semi, EOF],
    "fact() ;" : [Semi, EOF],
    "fact(int a) ;" : [Semi, EOF],
    "fib(int a, int b) ;" : [Semi, EOF],
    "arr[] ;" : [Semi, EOF],
    "arr[10] ;" : [Semi, EOF],
    //"(*fptr)(int, int) ;" : [Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DirectDeclarator::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//initDeclarator
//    : declarator ('=' initializer)?
//    ;
struct InitDeclarator {
  declarator: Declarator
  initializer: Initializer?
} derive(Show, Eq)

fn InitDeclarator::parse(toks: ArrayView[Token], ctx: Context) -> (InitDeclarator, ArrayView[Token]) raise {
  let (declarator, rest_toks) = Declarator::parse(toks, ctx);
  if rest_toks is [Assign, .. rest_toks] {
    let (initializer, rest_toks) = Initializer::parse(rest_toks, ctx);
    (InitDeclarator::{ declarator, initializer: Some(initializer) }, rest_toks)
  } else {
    (InitDeclarator::{ declarator, initializer: None }, rest_toks)
  }
}

test "InitDeclarator Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "a;" : [Semi, EOF],
    "b = 10;" : [Semi, EOF],
    "arr[] = {1, 2, 3, 4, 5};" : [Semi, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = InitDeclarator::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

type InitDeclaratorList Array[InitDeclarator] derive(Show, Eq)

fn InitDeclaratorList::parse(toks: ArrayView[Token], ctx: Context) -> (InitDeclaratorList, ArrayView[Token]) raise {
  let decls: Array[InitDeclarator] = Array::new()
  let (first_decl, rest_toks) = InitDeclarator::parse(toks, ctx);
  decls.push(first_decl)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_decl, rest) = InitDeclarator::parse(rest_toks, ctx);
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
enum Initializer {
  AssignExpr(AssignExpr)
  InitList(Array[(Array[Designator], Initializer)])
} derive(Show, Eq)


fn Initializer::parse(toks: ArrayView[Token], ctx: Context) -> (Initializer, ArrayView[Token]) raise {
  match toks {
    [LBrace, ..] as toks => {
      let (init_list, rest) = InitializerList::parse(toks, ctx);
      (Initializer::InitList(init_list.inner()), rest)
    }
    _ => {
      let (assign_expr, rest) = AssignExpr::parse(toks, ctx);
      (Initializer::AssignExpr(assign_expr), rest)
    }
  }
}

type InitializerList Array[(Array[Designator], Initializer)] derive(Show, Eq)

fn InitializerList::parse(toks: ArrayView[Token], ctx: Context) -> (InitializerList, ArrayView[Token]) raise {
  guard toks is [LBrace, .. toks] else {
    raise ParseError("Expected '{' to start initializer list")
  }
  let init_list: Array[(Array[Designator], Initializer)] = Array::new()
  loop toks {
    [Dot | LBracket, ..] as toks => {
      let (designators, rest) = DesignatorList::parse(toks, ctx);
      guard rest is [Assign, .. rest] else {
        raise ParseError("Expected '=' after designator list in initializer")
      }
      let (initializer, rest) = Initializer::parse(rest, ctx);
      init_list.push((designators.inner(), initializer))
      continue rest
    }
    [Comma, .. rest_toks] => {
      // Skip commas
      continue rest_toks
    }
    [RBrace, .. rest_toks] => {
      // End of initializer list
      break (InitializerList(init_list), rest_toks)
    }
    toks => { 
      // If we reach here, it means we have an initializer without designators
      let (initializer, rest) = Initializer::parse(toks, ctx);
      init_list.push((Array::new(), initializer))
      continue rest
    }
  }
}

test "InitializerList Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "{1, 2, 3}" : [EOF],
    "{.field = 1, .other = 2}" : [EOF],
    "{[0] = 1, [1] = 2}" : [EOF],
    "{.field = {1, 2}, .other = {3}}" : [EOF],
    "{{1, 2}, {3, 4}}" : [EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = InitializerList::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

//designator
//    : '[' constantExpression ']'
//    | '.' Identifier
//    ;
enum Designator {
  ConstExpr(ConstantExpr)
  DotAccess(String)
} derive(Show, Eq)

fn Designator::parse(toks: ArrayView[Token], ctx: Context) -> (Designator, ArrayView[Token]) raise {
  match toks {
    [LBracket, .. rest_toks] => {
      let (const_expr, rest) = ConstantExpr::parse(rest_toks, ctx);
      guard rest is [RBracket, .. rest] else {
        raise ParseError("Expected closing bracket after constant expression in designator")
      }
      (Designator::ConstExpr(const_expr), rest)
    }
    [Dot, Identifier(name), .. rest_toks] => (Designator::DotAccess(name), rest_toks)
    toks => raise ParseError("Unimplemented designator parsing, current token: \{toks[0]}")
  }
}

type DesignatorList Array[Designator] derive(Show, Eq)

fn DesignatorList::parse(toks: ArrayView[Token], ctx: Context) -> (DesignatorList, ArrayView[Token]) raise {
  let designators: Array[Designator] = Array::new()
  let rest_toks = loop toks {
    [LBracket | Dot, ..] as toks => {
      let (designator, rest) = Designator::parse(toks, ctx);
      designators.push(designator)
      continue rest
    }
    toks => break toks // no more designators
  }
  (DesignatorList(designators), rest_toks)
}

test "DesignatorList Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "[0]" : [EOF],
    ".field" : [EOF],
    "[1].field" : [EOF],
    "[2][3].field" : [EOF],
    "[1].field[2]" : [EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = DesignatorList::parse(toks, ctx);
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
struct EnumSpec {
  name: String?
  enumerators: Array[Enumerator]
} derive(Show, Eq)

fn EnumSpec::parse(toks: ArrayView[Token]) -> (EnumSpec, ArrayView[Token]) raise {
  ...
}

type Enumerator (String, ConstantExpr?) derive(Show, Eq)


//functionSpecifier
//    : 'inline'
//    | '_Noreturn'
//    | '__inline__' // GCC extension
//    | '__stdcall'
//    | gccAttributeSpecifier
//    | '__declspec' '(' Identifier ')'
//    ;
enum FunctionSpec {
  Inline // inline
  Noreturn // _Noreturn
} derive(Show, Eq)

fn FunctionSpec::parse(toks: ArrayView[Token]) -> (FunctionSpec, ArrayView[Token]) raise {
  match toks {
    [Inline, .. rest_toks] => (FunctionSpec::Inline, rest_toks)
    [Noreturn, .. rest_toks] => (FunctionSpec::Noreturn, rest_toks)
    _ => raise ParseError("Unimplemented function specifier")
  }
}

enum AlignmentSpec {
  AlignasExpr(ConstantExpr) // _Alignas(expr)
  AlignasType(TypeName) // _Alignof(type)
} derive(Show, Eq)

fn AlignmentSpec::parse(toks: ArrayView[Token], ctx: Context) -> (AlignmentSpec, ArrayView[Token]) raise {
  match toks {
    [Alignas, LParen, .. rest_toks] => {
      let (expr, rest) = ConstantExpr::parse(rest_toks, ctx);
      guard rest is [RParen, .. rest] else {
        raise ParseError("Expected closing parenthesis after expression in _Alignas")
      }
      (AlignmentSpec::AlignasExpr(expr), rest)
    }
    [Alignof, LParen, .. rest_toks] => {
      let (type_name, rest) = TypeName::parse(rest_toks, ctx);
      guard rest is [RParen, .. rest] else {
        raise ParseError("Expected closing parenthesis after type name in _Alignof")
      }
      (AlignmentSpec::AlignasType(type_name), rest)
    }
    _ => raise ParseError("Unimplemented alignment specifier")
  }
}


//typeName
//    : specifierQualifierList abstractDeclarator?
//    ;
struct TypeName {
  specifiers: Array[TypeSpecOrQualifier]
  abstract_declarator: AbstractDeclarator?
} derive(Show, Eq)

fn TypeName::parse(toks: ArrayView[Token], ctx: Context) -> (TypeName, ArrayView[Token]) raise {
  let specifiers: Array[TypeSpecOrQualifier] = Array::new()
  let mut rest_toks = toks
  while (try? TypeSpecOrQualifier::parse(rest_toks, ctx)) is Ok((spec, rest)) {
    specifiers.push(spec)
    rest_toks = rest
  }
  let (abstract_declarator, rest_toks) = if rest_toks is [Star | LParen | LBracket, ..] { 
    let (a, rest) = AbstractDeclarator::parse(rest_toks);
    (Some(a), rest)
  } else {
    (None, rest_toks)
  }
  let type_name = TypeName::{
    specifiers,
    abstract_declarator
  }
  (type_name, rest_toks)
}

//abstractDeclarator
//    : pointer
//    | pointer? directAbstractDeclarator gccDeclaratorExtension*
//    ;
struct AbstractDeclarator {
  pointer: Pointer?
  directAbstractDeclarator: DirectAbstractDeclarator?
} derive(Show, Eq)

fn AbstractDeclarator::parse(toks: ArrayView[Token]) -> (AbstractDeclarator, ArrayView[Token]) raise {
  match toks {
    [Star, ..] => {
      let (pointer, rest_toks) = Pointer::parse(toks);
      let (direct_abstract_declarator, rest_toks) = DirectAbstractDeclarator::parse(rest_toks);
      let abstract_declarator = AbstractDeclarator::{
        pointer: Some(pointer),
        directAbstractDeclarator: direct_abstract_declarator
      }
      (abstract_declarator, rest_toks)
    }
    [LParen | LBracket, ..] as toks => {
      let (direct_abstract_declarator, rest_toks) = DirectAbstractDeclarator::parse(toks);
      let abstract_declarator = AbstractDeclarator::{
        pointer: None,
        directAbstractDeclarator: direct_abstract_declarator
      }
      (abstract_declarator, rest_toks)
    }
    _ => raise ParseError("Expected pointer or direct abstract declarator")
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
enum DirectAbstractDeclarator {
  Array(Array[TypeQualifier], AssignExpr?)
  StaticArray(Array[TypeQualifier], AssignExpr)
  ArrayStatic(Array[TypeQualifier], AssignExpr)
  StarArray
  FuncPtr(Array[ParameterDecl])
} derive(Show, Eq)

// TODO: Not Correct Implementation
fn DirectAbstractDeclarator::parse(toks: ArrayView[Token]) -> (DirectAbstractDeclarator?, ArrayView[Token]) {
  (None, toks)
}

test "TypeName Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "int *ptr" : [Identifier("ptr"), EOF],
    "char **str" : [Identifier("str"), EOF],
    "const char ** msg" : [Identifier("msg"), EOF],
    "int const * arr" : [Identifier("arr"), EOF],
    "int * const arr" : [Identifier("arr"), EOF],
  }

  for code, expect_rest in code_expect_rest {
    //let toks = lex(code)
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = TypeName::parse(toks, ctx);
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
enum Statement {
  LabeledStatement(LabeledStatement)
  CompoundStatement(Array[BlockItem])
  ExpressionStatement(Expr)
  SelectionStatement(SelectionStatement)
  IterationStatement(IterationStatement)
  JumpStatement(JumpStatement)
  // Asm
  // volatile
} derive(Show, Eq)

fn Statement::parse(toks: ArrayView[Token], ctx: Context) -> (Statement, ArrayView[Token]) raise {
  match toks {
    [LBracket, ..] as toks => {
      let (compound_statement, rest_toks) = CompoundStatement::parse(toks, ctx);
      (Statement::CompoundStatement(compound_statement.inner()), rest_toks)
    }
    [If | Switch, ..] as toks => {
      let (selection_statement, rest_toks) = SelectionStatement::parse(toks, ctx);
      (Statement::SelectionStatement(selection_statement), rest_toks)
    }
    [For | While | Do, ..] as toks => {
      let (iteration_statement, rest_toks) = IterationStatement::parse(toks, ctx);
      (Statement::IterationStatement(iteration_statement), rest_toks)
    }
    [Identifier(_), Colon, .. rest_toks] => {
      let (labeled_statement, rest_toks) = LabeledStatement::parse(toks, ctx);
      (Statement::LabeledStatement(labeled_statement), rest_toks)
    }
    [Case | Default, ..] as toks => {
      let (labeled_statement, rest_toks) = LabeledStatement::parse(toks, ctx);
      (Statement::LabeledStatement(labeled_statement), rest_toks)
    }
    [Goto | Continue | Break | Return, ..] as toks => {
      let (jump_statement, rest_toks) = JumpStatement::parse(toks, ctx);
      (Statement::JumpStatement(jump_statement), rest_toks)
    }
    [Semi, .. ] => {
      raise ParseError("Empty statement, should skip it")
    }
    _ => {
      let (expr, rest_toks) = Expr::parse(toks, ctx);
      guard rest_toks is [Semi, .. rest_toks] else {
        raise ParseError("Expected ';' after expression statement")
      }
      (Statement::ExpressionStatement(expr), rest_toks)
    }
  }
}

//labeledStatement
//    : Identifier ':' statement
//    | 'case' constantExpression ':' statement
//    | 'default' ':' statement
//    ;
enum LabeledStatement {
  Label(String, Statement)
  Case(ConstantExpr, Statement)
  Default(Statement)
} derive(Show, Eq)

fn LabeledStatement::parse(toks: ArrayView[Token], ctx: Context) -> (LabeledStatement, ArrayView[Token]) raise {
  match toks {
    [Identifier(name), Colon, .. rest_toks] => {
      let (statement, rest_toks) = Statement::parse(rest_toks, ctx);
      (LabeledStatement::Label(name, statement), rest_toks)
    }
    [Case, ..rest_toks] => {
      let (const_expr, rest_toks) = ConstantExpr::parse(rest_toks, ctx);
      guard rest_toks is [Colon, .. rest_toks] else {
        raise ParseError("Expected ':' after case constant expression")
      }
      let (statement, rest_toks) = Statement::parse(rest_toks, ctx);
      (LabeledStatement::Case(const_expr, statement), rest_toks)
    }
    [Default, Colon, .. rest_toks] => {
      let (statement, rest_toks) = Statement::parse(rest_toks, ctx);
      (LabeledStatement::Default(statement), rest_toks)
    }
    rest_toks => {
      raise ParseError("Expected labeled statement, current token is \{rest_toks[0]}")
    }
  }
}

type CompoundStatement Array[BlockItem] derive(Show, Eq)

fn CompoundStatement::parse(toks: ArrayView[Token], ctx: Context) -> (CompoundStatement, ArrayView[Token]) raise {
  guard toks is [LBracket, .. toks] else {
    raise ParseError("Expected '{' for compound statement")
  }
  let items: Array[BlockItem] = Array::new()
  loop toks {
    [RBracket, .. rest_toks] => {
      break (CompoundStatement(items), rest_toks) // End of compound statement
    }
    [Semi, .. rest_toks] => {
      // Empty statement, just skip it
      continue rest_toks
    }
    toks => {
      let (item, rest_toks) = BlockItem::parse(toks, ctx);
      items.push(item);
      continue rest_toks
    }
  }
}

enum BlockItem {
  Statement(Statement)
  Declaration(Declaration)
} derive(Show, Eq)

fn BlockItem::parse(toks: ArrayView[Token], ctx: Context) -> (BlockItem, ArrayView[Token]) raise {
  if ctx.is_declspec_tok(toks[0]) {
    let (decl, rest_toks) = Declaration::parse(toks, ctx);
    (BlockItem::Declaration(decl), rest_toks)
  } else {
    let (stmt, rest_toks) = Statement::parse(toks, ctx);
    (BlockItem::Statement(stmt), rest_toks)
  }
}

enum SelectionStatement {
  If(Expr, Statement, Statement?)
  Switch(Expr, Statement)
} derive(Show, Eq)

fn SelectionStatement::parse(toks: ArrayView[Token], ctx: Context) -> (SelectionStatement, ArrayView[Token]) raise {
  match toks {
    [If, LParen, .. rest_toks] => {
      let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
      guard rest_toks is [RParen, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis after if condition")
      }
      let (then_stmt, rest_toks) = Statement::parse(rest_toks, ctx);
      let (else_stmt, rest_toks) = if rest_toks is [Else, .. rest_toks] {
        let (else_stmt, rest_toks) = Statement::parse(rest_toks, ctx);
        (Some(else_stmt), rest_toks)
      } else {
        (None, rest_toks)
      }
      (SelectionStatement::If(expr, then_stmt, else_stmt), rest_toks)
    }
    [Switch, LParen, .. rest_toks] => {
      let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
      guard rest_toks is [RParen, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis after switch condition")
      }
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx);
      (SelectionStatement::Switch(expr, stmt), rest_toks)
    }
    _ => raise ParseError("Unimplemented selection statement parsing")
  }
}

enum IterationStatement {
  While(Expr, Statement)
  DoWhile(Statement, Expr)
  For(ForCondition, Statement)
} derive(Show, Eq)

fn IterationStatement::parse(toks: ArrayView[Token], ctx: Context) -> (IterationStatement, ArrayView[Token]) raise {
  match toks {
    [While, LParen, .. rest_toks] => {
      let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
      guard rest_toks is [RParen, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis after while condition")
      }
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx);
      (IterationStatement::While(expr, stmt), rest_toks)
    }
    [Do, .. rest_toks] => {
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx);
      guard rest_toks is [While, LParen, .. rest_toks] else {
        raise ParseError("Expected 'while' after do-while statement")
      }
      let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
      guard rest_toks is [RParen, Semi, .. rest_toks] else {
        raise ParseError("Expected closing parenthesis and ';' after do-while condition")
      }
      (IterationStatement::DoWhile(stmt, expr), rest_toks)
    }
    [For, ..] => {
      let (for_cond, rest_toks) = ForCondition::parse(toks, ctx);
      let (stmt, rest_toks) = Statement::parse(rest_toks, ctx);
      (IterationStatement::For(for_cond, stmt), rest_toks)
    }
    _ => raise ParseError("Unimplemented iteration statement parsing")
  }
}

//forCondition
//    : (forDeclaration | expression?) ';' forExpression? ';' forExpression?
//    ;
struct ForCondition {
  for_init: ForInit
  cond: Array[AssignExpr]
  inc: Array[AssignExpr]
} derive(Show, Eq)

fn ForCondition::parse(toks: ArrayView[Token], ctx: Context) -> (ForCondition, ArrayView[Token]) raise {
  guard toks is [For, LParen, .. toks] else {
    raise ParseError("Expected 'for' condition to start with 'for('")
  }
  let (for_init, rest_toks) = ForInit::parse(toks, ctx);
  let (cond, rest_toks) = if rest_toks is [Semi, .. rest_toks] {
    (Array::new(), rest_toks) // No condition
  } else {
    let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
    guard rest_toks is [Semi, .. rest_toks] else {
      raise ParseError("Expected ';' after for condition expression")
    }
    (expr.exprs, rest_toks)
  }

  let (inc, rest_toks) = if rest_toks is [Semi, .. rest_toks] {
    (Array::new(), rest_toks) // No increment
  } else {
    let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
    guard rest_toks is [RParen, Semi, .. rest_toks] else {
      raise ParseError("Expected closing parenthesis and ';' after for increment expression")
    }
    (expr.exprs, rest_toks)
  }
  guard rest_toks is [RParen, .. rest_toks] else {
    raise ParseError("Expected closing parenthesis after for condition")
  }
  let for_condition = ForCondition::{ for_init, cond, inc }
  (for_condition, rest_toks)
}

struct ForInit {
  decl: Array[Declaration]
  initDecl: Array[InitDeclarator]
} derive(Show, Eq)

fn ForInit::parse(toks: ArrayView[Token], ctx: Context) -> (ForInit, ArrayView[Token]) raise {
  let decls: Array[Declaration] = Array::new()
  let init_decls: Array[InitDeclarator] = Array::new()
  loop toks {
    [Semi, .. rest_toks] => {
      // Empty initialization, just skip it
      break (ForInit::{ decl: decls, initDecl: init_decls }, rest_toks)
    }
    [Comma, .. rest_toks] => {
      // Skip commas
      continue rest_toks
    }
    [tok, ..] as toks if ctx.is_declspec_tok(tok) => {
      let (decl, rest_toks) = Declaration::parse(toks, ctx);
      decls.push(decl);
      continue rest_toks
    }
    toks => {
      let (init_decl, rest_toks) = InitDeclarator::parse(toks, ctx);
      init_decls.push(init_decl);
      continue rest_toks
    }
  }
}

enum JumpStatement {
  Goto(String)
  Continue
  Break
  Return(Expr?)
} derive(Show, Eq)

fn JumpStatement::parse(toks: ArrayView[Token], ctx: Context) -> (JumpStatement, ArrayView[Token]) raise {
  match toks {
    [Goto, Identifier(name), Semi, .. rest_toks] => (JumpStatement::Goto(name), rest_toks)
    [Continue, Semi, .. rest_toks] => (JumpStatement::Continue, rest_toks)
    [Break, Semi, .. rest_toks] => (JumpStatement::Break, rest_toks)
    [Return, Semi, .. rest_toks] => (JumpStatement::Return(None), rest_toks)
    [Return, .. rest_toks] => {
      let (expr, rest_toks) = Expr::parse(rest_toks, ctx);
      guard rest_toks is [Semi, .. rest_toks] else {
        raise ParseError("Expected ';' after return expression")
      }
      (JumpStatement::Return(Some(expr)), rest_toks)
    }
    _ => raise ParseError("Unimplemented jump statement parsing")
  }
}

test "Jump Statement Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "goto label;" : [EOF],
    "continue;" : [EOF],
    "break;" : [EOF],
    "return;" : [EOF],
    "return 42;" : [EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = JumpStatement::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

struct CompilationUnit {
  externalDeclatyons: Array[ExternalDeclaration]
} derive(Show, Eq)

enum ExternalDeclaration {
  FunctionDefinition(FunctionDefinition)
  Declaration(Declaration)
} derive(Show, Eq)

struct FunctionDefinition {
  declSpecs: Array[DeclSpec]
  declarator: Declarator
  declarations: Array[Declaration]
  body: Array[BlockItem]
} derive(Show, Eq)


//parameterTypeList
//    : parameterList (',' '...')?
//    ;

struct ParameterTypeList {
  params: Array[ParameterDecl]
  variadic: Bool
} derive(Show, Eq)

fn ParameterTypeList::parse(toks: ArrayView[Token], ctx: Context) -> (ParameterTypeList, ArrayView[Token]) raise {
  let (params, rest_toks) = ParameterList::parse(toks, ctx);
  let params = params.inner()
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

type ParameterList Array[ParameterDecl] derive(Show, Eq)

fn ParameterList::parse(toks: ArrayView[Token], ctx: Context) -> (ParameterList, ArrayView[Token]) raise {
  let decls: Array[ParameterDecl] = Array::new()
  let (first_decl, rest_toks) = ParameterDecl::parse(toks, ctx);
  decls.push(first_decl)
  let rest_toks = loop rest_toks {
    [Comma, .. rest_toks] => {
      let (next_decl, rest) = ParameterDecl::parse(rest_toks, ctx);
      decls.push(next_decl)
      continue rest
    }
    [RParen, ..] as rest_toks => {
      break rest_toks // End of parameter list
    }
    rest_toks => raise ParseError("Expected ',' or ')' in parameter list, current token is \{rest_toks[0]}")
  }
  let param_list = ParameterList(decls)
  (param_list, rest_toks)
}

test "ParameterList Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "int a, char *b, const int c, float d)" : [RParen, EOF],
    "int a, char *b)" : [RParen, EOF],
    "const int c)" : [RParen, EOF],
    "float d)" : [RParen, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ParameterList::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}


//parameterDeclaration
//    : declarationSpecifiers (declarator | abstractDeclarator)
//    ;
struct ParameterDecl {
  declspecs: Array[DeclSpec]
  declarator: ParamDeclarator
} derive(Show, Eq)

fn ParameterDecl::parse(toks: ArrayView[Token], ctx: Context) -> (ParameterDecl, ArrayView[Token]) raise {
  let (decl_specs, rest_toks) = DeclSpecList::parse(toks, ctx);
  let decl_specs = decl_specs.inner()
  guard decl_specs.length() > 0 else {
    raise ParseError("Parameter declaration must have at least one declaration specifier")
  }
  let (declarator, rest_toks) = ParamDeclarator::parse(rest_toks, ctx);
  let param_decl = ParameterDecl::{
    declspecs: decl_specs,
    declarator
  }
  (param_decl, rest_toks)
}

test "ParameterDecl Parsing Test" {
  let code_expect_rest: Map[String, ArrayView[Token]] = {
    "int a, " : [Comma, EOF],
    "char *b ," : [Comma, EOF],
    "const int c," : [Comma, EOF],
    "float d)" : [RParen, EOF],
  }

  for code, expect_rest in code_expect_rest {
    let ctx = Context::create(code)
    ctx.tokenize()
    let toks = ctx.alltoks
    let (_, rest_toks) = ParameterDecl::parse(toks, ctx);
    assert_eq(rest_toks, expect_rest)
  }
}

enum ParamDeclarator {
  Declarator(Declarator)
  AbstractDeclarator(AbstractDeclarator)
} derive(Show, Eq)

fn ParamDeclarator::parse(toks: ArrayView[Token], ctx: Context) -> (ParamDeclarator, ArrayView[Token]) raise {
  if (try? Declarator::parse(toks, ctx)) is Ok((declarator, rest_toks)) && rest_toks is [Comma | RParen, ..] {
    (ParamDeclarator::Declarator(declarator), rest_toks)
  } else if (try? AbstractDeclarator::parse(toks)) is Ok((abstract_declarator, rest_toks)) && rest_toks is [Comma | RParen, ..] {
    (ParamDeclarator::AbstractDeclarator(abstract_declarator), rest_toks)
  } else {
    raise ParseError("Expected declarator or abstract declarator in parameter declaration, current tok is \{toks[0]}")
  }
}
