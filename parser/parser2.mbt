//pub suberror ParseError(String) derive(Show)
//
////primaryExpression
////    : Identifier
////    | Constant
////    | StringLiteral+
////    | '(' expression ')'
////    | genericSelection
////    | '__extension__'? '(' compoundStatement ')' // Blocks (GCC extension)
////    | '__builtin_va_arg' '(' unaryExpression ',' typeName ')'
////    | '__builtin_offsetof' '(' typeName ',' unaryExpression ')'
////    ;
//enum PrimExpr {
//  Identifier(String)
//  Constant(Constant)
//  StringLiteral(String)
//  ParenExpr(Expr)
//  //GenericSelection
//} derive(Show, Eq)
//
////fn PrimExpr::parse(toks: ArrayView[Token]) -> (PrimExpr, ArrayView[Token]) raise {
//fn Context::parse_prim_expr(self: Self) -> PrimExpr raise {
//  match self.rest_toks {
//    [Identifier(name), .. rest_toks] => {
//      self.rest_toks = rest_toks
//      PrimExpr::Identifier(name)
//    }
//    [Constant(constant), .. rest_toks] => {
//      self.rest_toks = rest_toks
//      PrimExpr::Constant(constant)
//    }
//    [StringLiteral(lit), .. rest_toks] => {
//      let mut str = lit
//      let rest_toks = loop rest_toks {
//        [StringLiteral(next_lit), .. next_rest] => {
//          str += next_lit
//          continue next_rest
//        }
//        rest_toks => break rest_toks
//      }
//      self.rest_toks = rest_toks
//      PrimExpr::StringLiteral(str)
//    }
//    [LParen, ..rest_toks] => {
//      self.rest_toks = rest_toks
//      let expr = self.parse_expr();
//      guard self.rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after expression")
//      }
//      self.rest_toks = rest_toks
//      PrimExpr::ParenExpr(expr)
//    }
//    curr_toks => {
//      raise ParseError("Parse PrimExpr failed, current token: \{curr_toks[0]}")
//    }
//  }
//}
//
//test "PrimExpr Parsing Test" {
//  let code_expect_rest : Map[String, (PrimExpr, ArrayView[Token])] = {
//    "abc + " : (PrimExpr::Identifier("abc"), [Plus, EOF]),
//    "123 - " : (PrimExpr::Constant(Constant::Int(123)), [Minus, EOF]),
//    "\"hello \" \"world\" ": (PrimExpr::StringLiteral("hello world"), [EOF]),
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let (expect_prim, expect_rest_toks) = expect_rest
//    let ctx = Context::create(code)
//    let prim = ctx..tokenize().parse_prim_expr()
//    assert_eq(prim, expect_prim)
//    assert_eq(ctx.rest_toks, expect_rest_toks)
//  }
//
//  //let code_expect_rest : Map[String, ArrayView[Token]] = {
//  //  "(abc + 123) - 456" : [Minus, Constant(Constant::Int(456)), EOF],
//  //  "(a + b) * c" : [Star, Identifier("c"), EOF],
//  //}
//  //for code, expect_rest in code_expect_rest {
//  //  let toks = lex(code)
//  //  let (_, rest_toks) = PrimExpr::parse(toks);
//  //  assert_eq(rest_toks, expect_rest)
//  //}
//}
//
////postfixExpression
////    : (primaryExpression | '__extension__'? '(' typeName ')' '{' initializerList ','? '}') (
////        '[' expression ']'
////        | '(' argumentExpressionList? ')'
////        | ('.' | '->') Identifier
////        | '++'
////        | '--'
////    )*
////    ;
//struct PostFixExpr {
//  prim: PrimExpr
//  suffixes: Array[PostFixSuffix]
//} derive(Show, Eq)
//
//fn Context::parse_posifix_expr(self: Self) -> PostFixExpr raise {
//  let prim = self.parse_prim_expr();
//  let suffixes = self.parse_postfix_suffixes();
//  let post_fix_expr = PostFixExpr::{ prim, suffixes }
//  post_fix_expr
//}
//
//enum PostFixSuffix {
//  Indexing(Expr)
//  Call(Array[AssignExpr])
//  DotAccess(String)
//  ArrowAccess(String)
//  PlusPlus
//  MinusMinus
//} derive(Show, Eq)
//
//fn Context::parse_postfix_suffixes(self: Self) -> Array[PostFixSuffix] raise {
//  let suffixes: Array[PostFixSuffix] = Array::new()
//  let rest_toks = loop self.rest_toks {
//    [PlusPlus, .. rest_toks] => {
//      suffixes.push(PostFixSuffix::PlusPlus)
//      continue rest_toks
//    }
//    [MinusMinus, .. rest_toks] => {
//      suffixes.push(PostFixSuffix::MinusMinus)
//      continue rest_toks
//    }
//    [Dot, Identifier(name), .. rest_toks] => {
//      suffixes.push(PostFixSuffix::DotAccess(name))
//      continue rest_toks
//    }
//    [Arrow, Identifier(name), .. rest_toks] => {
//      suffixes.push(PostFixSuffix::ArrowAccess(name))
//      continue rest_toks
//    }
//    [LBracket, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let expr = self.parse_expr();
//      guard self.rest_toks is [RBracket, .. rest_toks] else {
//        raise ParseError("Expected closing bracket after expression")
//      }
//      suffixes.push(PostFixSuffix::Indexing(expr))
//      continue rest_toks
//    }
//    [LParen, .. rest_toks] => {
//      let args: Array[AssignExpr] = Array::new()
//      let rest_toks = loop rest_toks {
//        [RParen, .. rest_toks] => break rest_toks
//        [Comma, .. rest_toks] => continue rest_toks
//        rest_toks => {
//          self.rest_toks = rest_toks
//          let arg = self.parse_assign_expr();
//          args.push(arg)
//          continue self.rest_toks
//        }
//      }
//      suffixes.push(PostFixSuffix::Call(args))
//      continue rest_toks
//    }
//    toks => {
//      break toks // No more postfix suffixes
//    }
//  }
//  self.rest_toks = rest_toks
//  suffixes
//}
//
//test "PostfixExpr Parsing Test" {
//  let code_expect_rest : Map[String, ArrayView[Token]] = {
//    "abc++ + b" : [Plus, Identifier("b"), EOF],
//    "abc-- + b" : [Plus, Identifier("b"), EOF],
//    "point.x * 9" : [Star, Constant(Constant::Int(9)), EOF],
//    "p->x / 3" : [Slash, Constant(Constant::Int(3)), EOF],
//    //"fact(42) * 7" : [Star, Constant(Constant::Int(7)), EOF],
//    //"printf(\"The number is %d\", 42);" : [Semi, EOF],
//    //"mat[0][i]++;": [Semi, EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_posifix_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
//
////unaryExpression
////    : ('++' | '--' | 'sizeof')* (
////        postfixExpression
////        | unaryOperator castExpression
////        | ('sizeof' | '_Alignof') '(' typeName ')'
////        | '&&' Identifier // GCC extension address of label
////    )
////    ;
//struct UnaryExpr {
//  prefixes: Array[UnaryPrefix]
//  body: UnaryExprBody
//} derive(Show, Eq)
//
//fn Context::parse_unary_expr(self: Self) -> UnaryExpr raise {
//  let prefixes = self.parse_unary_prefixes();
//  let body = self.parse_unary_expr_body();
//  UnaryExpr::{ prefixes, body }
//}
//
//enum UnaryPrefix {
//  PlusPlus
//  MinusMinus
//  Sizeof
//} derive(Show, Eq)
//
//fn Context::parse_unary_prefixes(self: Self) -> Array[UnaryPrefix] {
//  let prefixes: Array[UnaryPrefix] = Array::new()
//  let rest_toks = loop self.rest_toks {
//    [PlusPlus, .. rest_toks] => {
//      prefixes.push(PlusPlus)
//      continue rest_toks
//    }
//    [MinusMinus, .. rest_toks] => {
//      prefixes.push(MinusMinus)
//      continue rest_toks
//    }
//    // if `sizeof(` check it if it is `sizeof(typename)`, if so, need to break
//    [Sizeof, LParen, .. rest_toks] as toks => {
//      self.rest_toks = rest_toks
//      match (try? self.parse_typename()) {
//        Err(_) => {
//          prefixes.push(UnaryPrefix::Sizeof)
//          self.rest_toks = toks[1:] // Restore the original token stream
//          continue toks[1:]
//        }
//        Ok(_) => break toks
//      }
//    }
//    [Sizeof, .. rest_toks] => {
//      prefixes.push(Sizeof)
//      continue rest_toks
//    }
//    toks => break toks // No more unary prefixes
//  }
//  self.rest_toks = rest_toks
//  prefixes
//}
//
//enum UnaryOperator {
//  AddressOf  // &
//  Dereference // *
//  Positive    // +
//  Negative    // -
//  LogicalNot  // !
//  BitwiseNot  // ~
//} derive(Show, Eq)
//
//fn Context::parse_unary_operator(self: Self) -> UnaryOperator raise {
//  let (op, rest_toks) = match self.rest_toks {
//    [And, .. rest_toks] => (AddressOf, rest_toks)
//    [Star, .. rest_toks] => (Dereference, rest_toks)
//    [Plus, .. rest_toks] => (Positive, rest_toks)
//    [Minus, .. rest_toks] => (Negative, rest_toks)
//    [Not, .. rest_toks] => (LogicalNot, rest_toks)
//    [Tilde, .. rest_toks] => (BitwiseNot, rest_toks)
//    _ => raise ParseError("Expected unary operator")
//  }
//  self.rest_toks = rest_toks
//  op
//}
//
//enum UnaryExprBody {
//  PostFix(PostFixExpr)
//  UnaryOp(UnaryOperator, CastExpr)
//  SizeofTypeName(TypeName)
//  AlignOfTypeName(TypeName)
//} derive(Show, Eq)
//
//fn Context::parse_unary_expr_body(self: Self) -> UnaryExprBody raise {
//  match self.rest_toks {
//    [And | Star | Plus | Minus | Not | Tilde as sym, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let cast_expr = self.parse_cast_expr();
//      let unary_op = match sym {
//        And => AddressOf
//        Star => Dereference
//        Plus => Positive
//        Minus => Negative
//        Not => LogicalNot
//        _ => BitwiseNot // Tilde
//      }
//      UnaryExprBody::UnaryOp(unary_op, cast_expr)
//    }
//    [Sizeof, LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_name = self.parse_typename();
//      guard rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after type name in sizeof")
//      }
//      self.rest_toks = rest_toks
//      UnaryExprBody::SizeofTypeName(type_name)
//    }
//    [Alignof, LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_name = self.parse_typename();
//      guard rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after type name in _Alignof")
//      }
//      self.rest_toks = rest_toks
//      UnaryExprBody::AlignOfTypeName(type_name)
//    }
//    _ => {
//      let post_fix_expr = self.parse_posifix_expr();
//      UnaryExprBody::PostFix(post_fix_expr)
//    }
//  }
//}
//
//test "UnaryExpr Parsing Test" {
//
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "++abc + b" : [Plus, Identifier("b"), EOF],
//    "--abc + b" : [Plus, Identifier("b"), EOF],
//    //"sizeof(int) + 1" : [Plus, Constant(Constant::Int(1)), EOF],
//    //"_Alignof(int) + 2" : [Plus, Constant(Constant::Int(2)), EOF],
//    //"&abc + b" : [Plus, Identifier("b"), EOF],
//    //"*abc + b" : [Plus, Identifier("b"), EOF],
//    //"+abc + b" : [Plus, Identifier("b"), EOF],
//    //"-abc + b" : [Plus, Identifier("b"), EOF],
//    //"!abc + b" : [Plus, Identifier("b"), EOF],
//    //"~abc + b" : [Plus, Identifier("b"), EOF],
//    //"++mat[i][j];" : [Semi, EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_unary_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////castExpression
////    : '__extension__'? '(' typeName ')' castExpression
////    | unaryExpression
////    | DigitSequence // for
////    ;
//struct CastExpr {
//  cast_types: Array[TypeName]
//  unary_expr: UnaryExpr
//} derive(Show, Eq)
//
//fn Context::parse_cast_expr(self: Self) -> CastExpr raise {
//  let cast_types: Array[TypeName] = Array::new()
//  loop self.rest_toks {
//    [LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_name = self.parse_typename();
//      guard self.rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after type name in cast")
//      }
//      self.rest_toks = rest_toks
//      cast_types.push(type_name)
//      continue rest_toks
//    }
//    _ => {
//      let unary_expr = self.parse_unary_expr();
//      break CastExpr::{ cast_types, unary_expr}
//    }
//  }
//}
//
//test "CastExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "(int)abc + b" : [Plus, Identifier("b"), EOF],
//    "(int)(float)abc + b" : [Plus, Identifier("b"), EOF],
//    "(int)123 + b" : [Plus, Identifier("b"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    //let toks = lex(code)
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_cast_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
//
////multiplicativeExpression
////    : castExpression (('*' | '/' | '%') castExpression)*
////    ;
//struct MultExpr {
//  exprs: Array[CastExpr]
//  ops: Array[MultOp]
//} derive(Show, Eq)
//
//enum MultOp {
//  Mult // *
//  Div // /
//  Mod // %
//} derive(Show, Eq)
//
//fn Context::parse_mult_expr(self: Self) -> MultExpr raise {
//  let exprs: Array[CastExpr] = Array::new()
//  let ops: Array[MultOp] = Array::new()
//  let first_expr = self.parse_cast_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [Star, .. rest_toks] => {
//      ops.push(MultOp::Mult)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_cast_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [Slash, .. rest_toks] => {
//      ops.push(MultOp::Div)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_cast_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [Mod, .. rest_toks] => {
//      ops.push(MultOp::Mod)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_cast_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  MultExpr::{ exprs, ops }
//}
//
//test "MultExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "abc * b + bbcc" : [Plus, Identifier("bbcc"), EOF],
//    "abc / b + a123" : [Plus, Identifier("a123"), EOF],
//    "abc % b - u89" : [Minus, Identifier("u89"), EOF],
//    "123 * 456 + 789" : [Plus, Constant(Constant::Int(789)), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_mult_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////additiveExpression
////    : multiplicativeExpression (('+' | '-') multiplicativeExpression)*
////    ;
//struct AddSubExpr {
//  exprs: Array[MultExpr]
//  ops: Array[AddSubOp]
//} derive(Show, Eq)
//
//enum AddSubOp {
//  Add // +
//  Sub // -
//} derive(Show, Eq)
//
//fn Context::parse_addsub_expr(self: Self) -> AddSubExpr raise {
//  let exprs: Array[MultExpr] = Array::new()
//  let ops: Array[AddSubOp] = Array::new()
//  let first_expr = self.parse_mult_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [Plus, .. rest_toks] => {
//      ops.push(AddSubOp::Add)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_mult_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [Minus, .. rest_toks] => {
//      ops.push(AddSubOp::Sub)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_mult_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  AddSubExpr::{ exprs, ops }
//}
//
//
//test "AddSubExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "abc + b - c > 78" : [GT, Constant(Constant::Int(78)), EOF],
//    "abc - b + d <= 96" : [LE, Constant(Constant::Int(96)), EOF],
//    "123 + 456 - 789 == 12345" : [EQ, Constant(Constant::Int(12345)), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_addsub_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////shiftExpression
////    : additiveExpression (('<<' | '>>') additiveExpression)*
////    ;
//struct ShiftExpr {
//  exprs: Array[AddSubExpr]
//  ops: Array[ShiftOp]
//} derive(Show, Eq)
//
//enum ShiftOp {
//  Shl // <<
//  Shr // >>
//} derive(Show, Eq)
//
//fn Context::parse_shift_expr(self: Self) -> ShiftExpr raise {
//  let exprs: Array[AddSubExpr] = Array::new()
//  let ops: Array[ShiftOp] = Array::new()
//  let first_expr = self.parse_addsub_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [Shl, .. rest_toks] => {
//      ops.push(ShiftOp::Shl)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_addsub_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [Shr, .. rest_toks] => {
//      ops.push(ShiftOp::Shr)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_addsub_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  ShiftExpr::{ exprs, ops }
//}
//
//test "ShiftExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a << 1 > 345 " : [GT, Constant(Constant::Int(345)), EOF],
//    "b >> 2 < 456" : [LT, Constant(Constant::Int(456)), EOF],
//    "c << 3 == 789" : [EQ, Constant(Constant::Int(789)), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_shift_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////relationalExpression
////    : shiftExpression (('<' | '>' | '<=' | '>=') shiftExpression)*
////    ;
//struct RelationalExpr {
//  exprs: Array[ShiftExpr]
//  ops: Array[RelationalOp]
//} derive(Show, Eq)
//
//enum RelationalOp {
//  LT // <
//  GT // >
//  LE // <=
//  GE // >=
//} derive(Show, Eq)
//
//fn Context::parse_relational_expr(self: Self) -> RelationalExpr raise {
//  let exprs: Array[ShiftExpr] = Array::new()
//  let ops: Array[RelationalOp] = Array::new()
//  let first_expr = self.parse_shift_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [LT, .. rest_toks] => {
//      ops.push(RelationalOp::LT)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_shift_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [GT, .. rest_toks] => {
//      ops.push(RelationalOp::GT)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_shift_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [LE, .. rest_toks] => {
//      ops.push(RelationalOp::LE)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_shift_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [GE, .. rest_toks] => {
//      ops.push(RelationalOp::GE)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_shift_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  RelationalExpr::{ exprs, ops }
//}
//
//test "RelationalExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a < b + c && True" : [DoubleAnd, Identifier("True"), EOF],
//    "d > e - f || False" : [DoubleOr, Identifier("False"), EOF],
//    "g <= h * i && cond" : [DoubleAnd, Identifier("cond"), EOF],
//    "j >= k / l || cond" : [DoubleOr, Identifier("cond"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_relational_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////equalityExpression
////    : relationalExpression (('==' | '!=') relationalExpression)*
////    ;
//struct EqualityExpr {
//  exprs: Array[RelationalExpr]
//  ops: Array[EqualityOp]
//} derive(Show, Eq)
//
//enum EqualityOp {
//  EQ // ==
//  NE // !=
//} derive(Show, Eq)
//
//fn Context::parse_equality_expr(self: Self) -> EqualityExpr raise {
//  let exprs: Array[RelationalExpr] = Array::new()
//  let ops: Array[EqualityOp] = Array::new()
//  let first_expr = self.parse_relational_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [EQ, .. rest_toks] => {
//      ops.push(EqualityOp::EQ)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_relational_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    [NE, .. rest_toks] => {
//      ops.push(EqualityOp::NE)
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_relational_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  EqualityExpr::{ exprs, ops }
//}
//
//test "EqualityExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a == b + c || True" : [DoubleOr, Identifier("True"), EOF],
//    "d != e - f && False" : [DoubleAnd, Identifier("False"), EOF],
//    "g == h * i || cond" : [DoubleOr, Identifier("cond"), EOF],
//    "j != k / l && cond" : [DoubleAnd, Identifier("cond"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_equality_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////andExpression
////    : equalityExpression ('&' equalityExpression)*
////    ;
//struct AndExpr {
//  exprs: Array[EqualityExpr]
//} derive(Show, Eq)
//
//fn Context::parse_and_expr(self: Self) -> AndExpr raise {
//  let exprs: Array[EqualityExpr] = Array::new()
//  let first_expr = self.parse_equality_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [And, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_equality_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  AndExpr::{ exprs }
//}
//
//test "AndExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a & b | c " : [Or, Identifier("c"), EOF],
//    "a & c ^ d" : [Xor, Identifier("d"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_and_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////exclusiveOrExpression
////    : andExpression ('^' andExpression)*
////    ;
//struct ExclusiveOrExpr {
//  exprs: Array[AndExpr]
//} derive(Show, Eq)
//
//fn Context::parse_exclusive_or_expr(self: Self) -> ExclusiveOrExpr raise {
//  let exprs: Array[AndExpr] = Array::new()
//  let first_expr = self.parse_and_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [Xor, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_and_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  ExclusiveOrExpr::{ exprs }
//}
//
//test "ExclusiveOrExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "1 & a ^ b ? c" : [Question, Identifier("c"), EOF],
//    "d ^ e & 1 ? f" : [Question, Identifier("f"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_exclusive_or_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////inclusiveOrExpression
////    : exclusiveOrExpression ('|' exclusiveOrExpression)*
////    ;
//struct InclusiveOrExpr {
//  exprs: Array[ExclusiveOrExpr]
//} derive(Show, Eq)
//
//fn Context::parse_inclusive_or_expr(self: Self) -> InclusiveOrExpr raise {
//  let exprs: Array[ExclusiveOrExpr] = Array::new()
//  let first_expr = self.parse_exclusive_or_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [Or, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_exclusive_or_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  InclusiveOrExpr::{ exprs }
//}
//
//test "InclusiveOrExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a | b ? c" : [Question, Identifier("c"), EOF],
//    "d | e ? f" : [Question, Identifier("f"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_inclusive_or_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////logicalAndExpression
////    : inclusiveOrExpression ('&&' inclusiveOrExpression)*
////    ;
//struct LogicalAndExpr {
//  exprs: Array[InclusiveOrExpr]
//} derive(Show, Eq)
//
//fn Context::parse_logical_and_expr(self: Self) -> LogicalAndExpr raise {
//  let exprs: Array[InclusiveOrExpr] = Array::new()
//  let first_expr = self.parse_inclusive_or_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [DoubleAnd, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_inclusive_or_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  LogicalAndExpr::{ exprs }
//}
//
//test "LogicalAndExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a && b || c" : [DoubleOr, Identifier("c"), EOF],
//    "d && e || f" : [DoubleOr, Identifier("f"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_logical_and_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////logicalOrExpression
////    : logicalAndExpression ('||' logicalAndExpression)*
////    ;
//struct LogicalOrExpr {
//  exprs: Array[LogicalAndExpr]
//} derive(Show, Eq)
//
//fn Context::parse_logical_or_expr(self: Self) -> LogicalOrExpr raise {
//  let exprs: Array[LogicalAndExpr] = Array::new()
//  let first_expr = self.parse_logical_and_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [DoubleOr, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_logical_and_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  LogicalOrExpr::{ exprs }
//}
//
//test "LogicalOrExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a || b ? c" : [Question, Identifier("c"), EOF],
//    "d || e ? f" : [Question, Identifier("f"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_logical_or_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////conditionalExpression
////    : logicalOrExpression ('?' expression ':' conditionalExpression)?
////    ;
//struct ConditionalExpr {
//  expr: LogicalOrExpr
//  select: (Expr, ConditionalExpr)?
//} derive(Show, Eq)
//
//fn Context::parse_conditional_expr(self: Self) -> ConditionalExpr raise {
//  let logical_or_expr = self.parse_logical_or_expr();
//  match self.rest_toks {
//    [Question, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let expr = self.parse_expr();
//      guard self.rest_toks is [Colon, .. rest_toks] else {
//        raise ParseError("Expected ':' after expression in conditional expression")
//      }
//      self.rest_toks = rest_toks // Skip the colon
//      let conditional_expr = self.parse_conditional_expr();
//      ConditionalExpr::{ expr: logical_or_expr, select: Some((expr, conditional_expr)) }
//    }
//    _ => ConditionalExpr::{ expr: logical_or_expr, select: None }
//  }
//}
//
//test "ConditionalExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "cond1 ? 123 : 456 ; int" : [Semi, Int, EOF],
//    "cond1 && cond2 ? abc : def ; struct" : [Semi, Struct, EOF],
//    "init || Next ? 7 : 8; " : [Semi, EOF],
//    "a123 += 5" : [PlusAssign, Constant(Constant::Int(5)), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_conditional_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
////assignmentExpression
////    : conditionalExpression
////    | unaryExpression assignmentOperator assignmentExpression
////    | DigitSequence // for
////    ;
//enum AssignExpr {
//  Conditional(ConditionalExpr)
//  Assign(UnaryExpr, AssignOp, AssignExpr)
//} derive(Show, Eq)
//
//fn Context::parse_assign_expr(self: Self) -> AssignExpr raise { 
//  let toks = self.rest_toks; // record current toks
//  let unary_expr = self.parse_unary_expr();
//  match self.rest_toks {
//    [Assign | PlusAssign | MinusAssign | StarAssign | DivAssign | ModAssign |
//     LeftShiftAssign | RightShiftAssign | AndAssign | BitXorAssign |
//     BitOrAssign as op, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let assign_expr = self.parse_assign_expr();
//      let assign_op = match op {
//        Assign => AssignOp::Assign
//        PlusAssign => AssignOp::AddAssign
//        MinusAssign => AssignOp::SubAssign
//        StarAssign => AssignOp::MultAssign
//        DivAssign => AssignOp::DivAssign
//        ModAssign => AssignOp::ModAssign
//        AndAssign => AssignOp::AndAssign
//        OrAssign => AssignOp::OrAssign
//        LeftShiftAssign => AssignOp::LeftShiftAssign
//        RightShiftAssign => AssignOp::RightShiftAssign
//        BitAndAssign => AssignOp::BitwiseAndAssign
//        BitXorAssign => AssignOp::BitwiseXorAssign
//        _ => AssignOp::BitwiseOrAssign // BitOrAssign
//      }
//      AssignExpr::Assign(unary_expr, assign_op, assign_expr)
//    }
//    _ => {
//      self.rest_toks = toks // Restore the original token stream
//      let cond_expr = self.parse_conditional_expr();
//      AssignExpr::Conditional(cond_expr)
//    }
//  }
//}
//
//test "AssignExpr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a = b + c; int" : [Semi, Int, EOF],
//    "x += 5; union" : [Semi, Union, EOF],
//    "cond1 && cond2 ? abc : def ; struct" : [Semi, Struct, EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_assign_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
//enum AssignOp {
//  Assign // =
//  AddAssign // +=
//  SubAssign // -=
//  MultAssign // *=
//  DivAssign // /=
//  ModAssign // %=
//  AndAssign // &&=
//  OrAssign // ||=
//  LeftShiftAssign // <<=
//  RightShiftAssign // >>=
//  BitwiseAndAssign // &=
//  BitwiseXorAssign // ^=
//  BitwiseOrAssign // |=
//} derive(Show, Eq)
//
////expression
////    : assignmentExpression (',' assignmentExpression)*
////    ;
//struct Expr {
//  exprs: Array[AssignExpr]
//} derive(Show, Eq)
//
//fn Context::parse_expr(self: Self) -> Expr raise {
//  let exprs: Array[AssignExpr] = Array::new()
//  let first_expr = self.parse_assign_expr();
//  exprs.push(first_expr)
//  loop self.rest_toks {
//    [Comma, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let next_expr = self.parse_assign_expr();
//      exprs.push(next_expr)
//      continue self.rest_toks
//    }
//    _ => break
//  }
//  Expr::{ exprs }
//}
//
//test "Expr Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "a = b + c, d = e - f; int" : [Semi, Int, EOF],
//    "x += 5, y -= 10; union" : [Semi, Union, EOF],
//    "cond1 && cond2 ? abc : def ; struct" : [Semi, Struct, EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_expr()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
//typealias ConditionalExpr as ConstantExpr
//
//fn Context::parse_constant_expr(self: Self) -> ConstantExpr raise {
//  self.parse_conditional_expr()
//}
//
////declaration
////    : declarationSpecifiers initDeclaratorList? ';'
////    | staticAssertDeclaration
////    ;
//enum Declaration {
//  Decl(Array[DeclSpec], Array[InitDeclarator])
//  //StaticAssertDecl(StaticAssertDecl)
//} derive(Show, Eq)
//
//enum DeclSpec {
//  StorageClassSpec(StorageClassSpec)
//  TypeSpec(TypeSpec)
//  TypeQualifier(TypeQualifier)
//  FunctionSpec(FunctionSpec)
//  AlignmentSpec(AlignmentSpec)
//} derive(Show, Eq)
//
////fn DeclSpec::parse(toks: ArrayView[Token]) -> (DeclSpec, ArrayView[Token]) raise {
//fn Context::parse_declspec(self: Self) -> DeclSpec raise {
//  match self.rest_toks {
//    [Auto | Register | Static | ThreadLocal | Extern | Typedef, ..] => {
//      let storage_class_spec = self.parse_storage_class_spec();
//      DeclSpec::StorageClassSpec(storage_class_spec)
//    }
//    [Const | Volatile | Restrict | Atomic, ..] => {
//      let type_qualifier = self.parse_type_qualifier();
//      DeclSpec::TypeQualifier(type_qualifier)
//    }
//    [Inline, Noreturn, ..] => {
//      let function_spec = self.parse_function_spec();
//      DeclSpec::FunctionSpec(function_spec)
//    }
//    [Alignas, ..] => {
//      let alignment_spec = self.parse_alignment_spec();
//      DeclSpec::AlignmentSpec(alignment_spec)
//    }
//    _ => {
//      let type_spec = self.parse_type_spec();
//      DeclSpec::TypeSpec(type_spec)
//    }
//  }
//}
//
//type DeclSpecList Array[DeclSpec] derive(Show, Eq)
//
//fn Context::parse_declspec_list(self: Self) -> Array[DeclSpec] {
//  let decl_specs: Array[DeclSpec] = Array::new()
//  while (try? self.parse_declspec()) is Ok(decl_spec) {
//    decl_specs.push(decl_spec)
//  }
//  decl_specs
//}
//
//test "DeclSpecList Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "int a;" : [Identifier("a"), Semi, EOF],
//    "const char *p;" : [Star, Identifier("p"), Semi, EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_declspec_list()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
//enum StorageClassSpec {
//  Auto // auto
//  Register // register
//  Static // static
//  ThreadLocal // _Thread_local
//  Extern // extern
//  Typedef // typedef
//} derive(Show, Eq)
//
////fn StorageClassSpec::parse(toks: ArrayView[Token]) -> (StorageClassSpec, ArrayView[Token]) raise {
//fn Context::parse_storage_class_spec(self: Self) -> StorageClassSpec raise {
//  let (spec, rest_toks) = match self.rest_toks {
//    [Auto, .. rest_toks] => (StorageClassSpec::Auto, rest_toks)
//    [Register, .. rest_toks] => (StorageClassSpec::Register, rest_toks)
//    [Static, .. rest_toks] => (StorageClassSpec::Static, rest_toks)
//    [ThreadLocal, .. rest_toks] => (StorageClassSpec::ThreadLocal, rest_toks)
//    [Extern, .. rest_toks] => (StorageClassSpec::Extern, rest_toks)
//    [Typedef, .. rest_toks] => (StorageClassSpec::Typedef, rest_toks)
//    _ => raise ParseError("Unimplemented storage class specifier")
//  }
//  self.rest_toks = rest_toks
//  spec
//}
//
////typeSpecifier
////    : 'void'
////    | 'char'
////    | 'short'
////    | 'int'
////    | 'long'
////    | 'float'
////    | 'double'
////    | 'signed'
////    | 'unsigned'
////    | '_Bool'
////    | '_Complex'
////    | '__m128'
////    | '__m128d'
////    | '__m128i'
////    | '__extension__' '(' ('__m128' | '__m128d' | '__m128i') ')'
////    | atomicTypeSpecifier
////    | structOrUnionSpecifier
////    | enumSpecifier
////    | typedefName
////    | '__typeof__' '(' constantExpression ')' // GCC extension
////    ;
//enum TypeSpec {
//  Void // void
//  Char // char
//  Short // short
//  Int // int
//  Long // long
//  Float // float
//  Double // double
//  Signed // signed
//  Unsigned // unsigned
//  Bool // _Bool
//  Complex // _Complex
//  Atomic(TypeName) // _Atomic(type)
//  StructSpec(StructSpec)
//  UnionSpec(UnionSpec)
//  EnumSpec(EnumSpec)
//  TypedefName(String)
//} derive(Show, Eq)
//
//fn Context::parse_type_spec(self: Self) -> TypeSpec raise {
//  let (spec, rest_toks) = match self.rest_toks {
//    [Void, .. rest_toks] => (TypeSpec::Void, rest_toks)
//    [Char, .. rest_toks] => (TypeSpec::Char, rest_toks)
//    [Short, .. rest_toks] => (TypeSpec::Short, rest_toks)
//    [Int, .. rest_toks] => (TypeSpec::Int, rest_toks)
//    [Long, .. rest_toks] => (TypeSpec::Long, rest_toks)
//    [Float, .. rest_toks] => (TypeSpec::Float, rest_toks)
//    [Double, .. rest_toks] => (TypeSpec::Double, rest_toks)
//    [Signed, .. rest_toks] => (TypeSpec::Signed, rest_toks)
//    [Unsigned, .. rest_toks] => (TypeSpec::Unsigned, rest_toks)
//    [Bool, .. rest_toks] => (TypeSpec::Bool, rest_toks)
//    [Complex, .. rest_toks] => (TypeSpec::Complex, rest_toks)
//    [Atomic, LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_name = self.parse_typename();
//      guard self.rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after type name in _Atomic")
//      }
//      (TypeSpec::Atomic(type_name), rest_toks)
//    }
//    [Struct, .. ] => {
//      let struct_spec = self.parse_struct_spec();
//      (TypeSpec::StructSpec(struct_spec), self.rest_toks)
//    }
//    [Union, .. ] => {
//      let union_spec = self.parse_union_spec();
//      (TypeSpec::UnionSpec(union_spec), self.rest_toks)
//    }
//    [Enum, ..] => {
//      let enum_spec = self.parse_enum_spec();
//      (TypeSpec::EnumSpec(enum_spec), self.rest_toks)
//    }
//    [Identifier(name), .. rest_toks] if self.typedefs.get(name) is Some(_) => (TypeSpec::TypedefName(name), rest_toks)
//    toks => raise ParseError("Parse TypeSpec Error, unexpect token \{toks[0]}")
//  }
//  self.rest_toks = rest_toks
//  spec
//}
//
//enum TypeQualifier {
//  Const // const
//  Volatile // volatile
//  Restrict // restrict
//  Atomic // _Atomic
//} derive(Show, Eq)
//
//fn Context::parse_type_qualifier(self: Self) -> TypeQualifier raise {
//  let (qual, rest_toks) = match self.rest_toks {
//    [Const, .. rest_toks] => (TypeQualifier::Const, rest_toks)
//    [Volatile, .. rest_toks] => (TypeQualifier::Volatile, rest_toks)
//    [Restrict, .. rest_toks] => (TypeQualifier::Restrict, rest_toks)
//    [Atomic, .. rest_toks] => (TypeQualifier::Atomic, rest_toks)
//    _ => raise ParseError("Unimplemented type qualifier")
//  }
//  self.rest_toks = rest_toks
//  qual
//}
//
//type TypeQualifierList Array[TypeQualifier] derive(Show, Eq)
//
////fn TypeQualifierList::parse(toks: ArrayView[Token]) -> (TypeQualifierList, ArrayView[Token]) {
//fn Context::parse_type_qualifier_list(self: Self) -> TypeQualifierList {
//  let qualifiers: Array[TypeQualifier] = Array::new()
//  let rest_toks = loop self.rest_toks {
//    [Const, .. rest_toks] => {
//      qualifiers.push(TypeQualifier::Const)
//      continue rest_toks
//    }
//    [Volatile, .. rest_toks] => {
//      qualifiers.push(TypeQualifier::Volatile)
//      continue rest_toks
//    }
//    [Restrict, .. rest_toks] => {
//      qualifiers.push(TypeQualifier::Restrict)
//      continue rest_toks
//    }
//    [Atomic, .. rest_toks] => {
//      qualifiers.push(TypeQualifier::Atomic)
//      continue rest_toks
//    }
//    toks => break toks // no more type qualifiers
//  }
//  self.rest_toks = rest_toks
//  qualifiers
//}
//
//fn TypeQualifierList::is_empty(self: Self) -> Bool {
//  self.inner().is_empty()
//}
//
//enum TypeSpecOrQualifier {
//  TypeSpec(TypeSpec)
//  TypeQualifier(TypeQualifier)
//} derive(Show, Eq)
//
//fn Context::parse_typespec_or_qualifier(self: Self) -> TypeSpecOrQualifier raise {
//  let (spec_or_qual, rest_toks) = match self.rest_toks {
//    [Const, .. rest_toks] => (TypeSpecOrQualifier::TypeQualifier(TypeQualifier::Const), rest_toks)
//    [Volatile, .. rest_toks] => (TypeQualifier(TypeQualifier::Volatile), rest_toks)
//    [Restrict, .. rest_toks] => (TypeQualifier(TypeQualifier::Restrict), rest_toks)
//    [Atomic, .. rest_toks] => (TypeQualifier(TypeQualifier::Atomic), rest_toks)
//    _ => {
//      let type_spec = self.parse_type_spec();
//      (TypeSpecOrQualifier::TypeSpec(type_spec), self.rest_toks)
//    }
//  }
//  self.rest_toks = rest_toks
//  spec_or_qual
//}
//
//struct StructSpec {
//  name: String?
//  decls: Array[StructDeclaration]
//} derive(Show, Eq)
//
//fn Context::parse_struct_spec(self: Self) -> StructSpec raise {
//  ...
//}
//
//struct UnionSpec {
//  name: String?
//  decls: Array[StructDeclaration]
//} derive(Show, Eq)
//
//fn Context::parse_union_spec(self: Self) -> UnionSpec raise {
//  ...
//}
//
////structDeclaration // The first two rules have priority order and cannot be simplified to one expression.
////    : specifierQualifierList structDeclaratorList ';'
////    | specifierQualifierList ';'
////    | staticAssertDeclaration
////    ;
//enum StructDeclaration {
//  Normal(Array[TypeSpecOrQualifier], Array[StructDeclarator])
//  //StaticAssertDecl(StaticAssertDecl)
//} derive(Show, Eq)
//
//enum StructOrUnionKind {
//  Struct // struct
//  Union // union
//} derive(Show, Eq)
//
//enum StructDeclarator {
//  Declarator(Declarator)
//  //Field(Declarator?, ConstantExpr)
//} derive(Show, Eq)
//
//struct Declarator {
//  pointer: Pointer?
//  directDeclarator: DirectDeclarator
//} derive(Show, Eq)
//
////fn Declarator::parse(toks: ArrayView[Token]) -> (Declarator, ArrayView[Token]) raise {
//fn Context::parse_declarator(self: Self) -> Declarator raise {
//  //let (pointer, rest_toks) = Pointer::parse(toks);
//  let pointer = self.parse_pointer();
//  let pointer = if pointer.inner().is_empty() {
//    None // No pointer qualifiers
//  } else {
//    Some(pointer)
//  }
//  let direct_declarator = self.parse_direct_declarator();
//  Declarator::{ pointer, directDeclarator: direct_declarator }
//}
//
////pointer
////    : (('*' | '^') typeQualifierList?)+ // ^ - Blocks language extension
////    ;
//type Pointer Array[TypeQualifier?]  derive(Show, Eq)
//
//fn Context::parse_pointer(self: Self) -> Pointer {
//  let qualifiers: Array[TypeQualifier?] = Array::new()
//  let rest_toks = loop self.rest_toks {
//    [Star, Const, ..rest_toks] => {
//      qualifiers.push(Some(Const))
//      continue rest_toks
//    }
//    [Star, Volatile, ..rest_toks] => {
//      qualifiers.push(Some(Volatile))
//      continue rest_toks
//    }
//    [Star, Restrict, ..rest_toks] => {
//      qualifiers.push(Some(Restrict))
//      continue rest_toks
//    }
//    [Star, Atomic, ..rest_toks] => {
//      qualifiers.push(Some(Atomic))
//      continue rest_toks
//    }
//    [Star, .. rest_toks] => {
//      qualifiers.push(None) // Pointer without type qualifier
//      continue rest_toks
//    }
//    toks => break toks // no more pointers
//  }
//  self.rest_toks = rest_toks
//  Pointer(qualifiers)
//}
//
//test "Pointer Parsing Test" {
//  let code_expect_rest: Map[String, ArrayView[Token]] = {
//    "*a": [Identifier("a"), EOF],
//    "**b": [Identifier("b"), EOF],
//    "* const Point": [Identifier("Point"), EOF],
//  }
//
//  for code, expect_rest in code_expect_rest {
//    let ctx = Context::create(code)
//    let _ = ctx..tokenize().parse_pointer()
//    assert_eq(ctx.rest_toks, expect_rest)
//  }
//}
//
//
////directDeclarator
////    : Identifier
////    | '(' declarator ')'
////    | directDeclarator '[' typeQualifierList? assignmentExpression? ']'
////    | directDeclarator '[' 'static' typeQualifierList? assignmentExpression ']'
////    | directDeclarator '[' typeQualifierList 'static' assignmentExpression ']'
////    | directDeclarator '[' typeQualifierList? '*' ']'
////    | directDeclarator '(' parameterTypeList ')'
////    | directDeclarator '(' identifierList? ')'
////    | Identifier ':' DigitSequence         // bit field
////    | vcSpecificModifer Identifier         // Visual C Extension
////    | '(' vcSpecificModifer declarator ')' // Visual C Extension
////    ;
//enum DirectDeclarator {
//  Identifier(String)
//  Parenthesized(Declarator)
//  Array(DirectDeclarator, TypeQualifierList, AssignExpr?)
//  StaticArray(DirectDeclarator, Array[TypeQualifier], AssignExpr)
//  VallengthArray(DirectDeclarator, Array[TypeQualifier])
//  //FunctionDecl(DirectDeclarator, ParameterTypeList)
//  FunctionPtr(DirectDeclarator, Array[String])
//  BitField(String, Int)
//} derive(Show, Eq)
//
//fn Context::parse_direct_declarator(self: Self) -> DirectDeclarator raise {
//  let head_decl = match self.rest_toks {
//    [Identifier(name), .. rest_toks] => {
//      self.rest_toks = rest_toks
//      DirectDeclarator::Identifier(name)
//    }
//    [LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let declarator = self.parse_declarator();
//      guard self.rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after declarator")
//      }
//      self.rest_toks = rest_toks
//      DirectDeclarator::Parenthesized(declarator)
//    }
//    _ => raise ParseError("Unimplemented direct declarator parsing")
//  }
//  let mut current_decl = head_decl
//  let rest_toks = loop self.rest_toks {
//    [LBracket, Static, ..rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_qualifiers = self.parse_type_qualifier_list();
//      let assign_expr = self.parse_assign_expr();
//      current_decl = DirectDeclarator::StaticArray(current_decl, type_qualifiers.inner(), assign_expr)
//      continue rest_toks
//    }
//    [LBracket, ..rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_qualifiers = self.parse_type_qualifier_list();
//      let rest_toks = match self.rest_toks {
//        [Static, .. rest_toks] => {
//          self.rest_toks = rest_toks
//          let assign_expr = self.parse_assign_expr();
//          current_decl = DirectDeclarator::StaticArray(current_decl, type_qualifiers.inner(), assign_expr)
//          guard self.rest_toks is [RBracket, ..rest_toks] else {
//            raise ParseError("Expected closing bracket after static array declaration")
//          }
//          rest_toks
//        }
//        [Star, .. rest_toks] => {
//          current_decl = DirectDeclarator::VallengthArray(current_decl, type_qualifiers.inner())
//          guard rest_toks is [RBracket, ..rest_toks] else {
//            raise ParseError("Expected closing bracket after variable length array declaration")
//          }
//          rest_toks
//        }
//        [RBracket, ..rest_toks] => {
//          current_decl = DirectDeclarator::Array(current_decl, type_qualifiers.inner(), None)
//          rest_toks
//        }
//        _ => {
//          let assign_expr = self.parse_assign_expr();
//          current_decl = DirectDeclarator::Array(current_decl, type_qualifiers.inner(), Some(assign_expr))
//          guard self.rest_toks is [RBracket, ..rest_toks] else {
//            raise ParseError("Expected closing bracket after array declaration")
//          }
//          rest_toks
//        }
//      }
//      continue rest_toks
//    }
//    // IdentifierList
//    [LParen, Identifier(name), Comma, ..rest_toks] => {
//      let identifiers: Array[String] = [name]
//      let rest_toks = loop rest_toks {
//        [Identifier(next_name), ..rest_toks] => {
//          identifiers.push(next_name)
//          continue rest_toks
//        }
//        [Comma, ..rest_toks] => continue rest_toks
//        [RParen, ..rest_toks] => {
//          break rest_toks
//        }
//        _ => raise ParseError("Expected identifier or closing parenthesis in identifier list")
//      }
//      current_decl = DirectDeclarator::FunctionPtr(current_decl, identifiers)
//      continue rest_toks
//    }
//    // IdentifierList
//    [LParen, Identifier(name), RParen, ..rest_toks] => {
//      let identifiers: Array[String] = [name]
//      current_decl = DirectDeclarator::FunctionPtr(current_decl, identifiers)
//      continue rest_toks
//    }
//    [LParen, RParen, ..rest_toks] => {
//      current_decl = DirectDeclarator::FunctionPtr(current_decl, [])
//      continue rest_toks
//    }
//    // parameterTypeList
//    [LParen, ..rest_toks] => {
//      raise ParseError("Unimplemented parameter type list parsing")
//      //let params = self.parse_parameter_type_list();
//      //current_decl = DirectDeclarator::FunctionDecl(current_decl, params);
//      //guard self.rest_toks is [RParen, ..rest_toks] else {
//      //  raise ParseError("Expected closing parenthesis after parameter type list")
//      //}
//      //continue rest_toks
//    }
//    // BitField
//    [Identifier(name), Colon, Constant(Int(i)), ..rest_toks] => {
//      current_decl = DirectDeclarator::BitField(name, i);
//      continue rest_toks
//    }
//    rest_toks => {
//      break rest_toks
//    }
//  }
//  self.rest_toks = rest_toks
//  current_decl
//}
//
//struct InitDeclarator {
//  declarator: Declarator
//  initializer: Initializer?
//} derive(Show, Eq)
//
//
////initializer
////    : assignmentExpression
////    | '{' initializerList ','? '}'
////    ;
////
////initializerList
////    : designation? initializer (',' designation? initializer)*
////    ;
////
////designation
////    : designatorList '='
////    ;
////
////designatorList
////    : designator+
////    ;
////
////designator
////    : '[' constantExpression ']'
////    | '.' Identifier
////    ;
//enum Initializer {
//  AssignExpr(AssignExpr)
//  InitList(Array[(Array[Designator], Initializer)])
//} derive(Show, Eq)
//
////designator
////    : '[' constantExpression ']'
////    | '.' Identifier
////    ;
//enum Designator {
//  //ConstExpr(ConstantExpr)
//  DotAccess(String)
//} derive(Show, Eq)
//
//
////enumSpecifier
////    : 'enum' Identifier? '{' enumeratorList ','? '}'
////    | 'enum' Identifier
////    ;
////
////enumeratorList
////    : enumerator (',' enumerator)*
////    ;
////
////enumerator
////    : enumerationConstant ('=' constantExpression)?
////    ;
////
////enumerationConstant
////    : Identifier
////    ;
//struct EnumSpec {
//  name: String?
//  //enumerators: Array[Enumerator]
//} derive(Show, Eq)
//
//fn Context::parse_enum_spec(self: Self) -> EnumSpec raise {
//  ...
//}
//
////type Enumerator (String, ConstantExpr?) derive(Show, Eq)
//
////functionSpecifier
////    : 'inline'
////    | '_Noreturn'
////    | '__inline__' // GCC extension
////    | '__stdcall'
////    | gccAttributeSpecifier
////    | '__declspec' '(' Identifier ')'
////    ;
//enum FunctionSpec {
//  Inline // inline
//  Noreturn // _Noreturn
//} derive(Show, Eq)
//
////fn FunctionSpec::parse(toks: ArrayView[Token]) -> (FunctionSpec, ArrayView[Token]) raise {
//fn Context::parse_function_spec(self: Self) -> FunctionSpec raise {
//  let (spec, toks) = match self.rest_toks {
//    [Inline, .. rest_toks] => (FunctionSpec::Inline, rest_toks)
//    [Noreturn, .. rest_toks] => (FunctionSpec::Noreturn, rest_toks)
//    _ => raise ParseError("Unimplemented function specifier")
//  }
//  self.rest_toks = toks
//  spec
//}
//
//enum AlignmentSpec {
//  AlignasExpr(ConstantExpr) // _Alignas(expr)
//  AlignasType(TypeName) // _Alignof(type)
//} derive(Show, Eq)
//
//fn Context::parse_alignment_spec(self: Self) -> AlignmentSpec raise {
//  match self.rest_toks {
//    [Alignas, LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let expr = self.parse_constant_expr();
//      guard self.rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after expression in _Alignas")
//      }
//      self.rest_toks = rest_toks
//      AlignmentSpec::AlignasExpr(expr)
//    }
//    [Alignof, LParen, .. rest_toks] => {
//      self.rest_toks = rest_toks
//      let type_name = self.parse_typename();
//      guard self.rest_toks is [RParen, .. rest_toks] else {
//        raise ParseError("Expected closing parenthesis after type name in _Alignof")
//      }
//      self.rest_toks = rest_toks
//      AlignmentSpec::AlignasType(type_name)
//    }
//    _ => raise ParseError("Unimplemented alignment specifier")
//  }
//}
//
//
////typeName
////    : specifierQualifierList abstractDeclarator?
////    ;
//struct TypeName {
//  specifiers: Array[TypeSpecOrQualifier]
//  abstract_declarator: AbstractDeclarator?
//} derive(Show, Eq)
//
////fn TypeName::parse(toks: ArrayView[Token]) -> (TypeName, ArrayView[Token]) raise {
//fn Context::parse_typename(self: Self) -> TypeName raise {
//  assert_eq(1, 1) // dumy
//  let specifiers: Array[TypeSpecOrQualifier] = Array::new()
//  while (try? self.parse_typespec_or_qualifier()) is Ok(spec) {
//    specifiers.push(spec)
//  }
//  let abstract_declarator = if self.rest_toks is [Star | LParen | LBracket, ..] {
//    let a = self.parse_abstract_declarator();
//    Some(a)
//  } else {
//    None
//  }
//  TypeName::{ 
//    specifiers, 
//    abstract_declarator 
//  }
//
//  //let (abstract_declarator, rest_toks) = if rest_toks is [Star | LParen | LBracket, ..] { 
//  //  let (a, rest) = AbstractDeclarator::parse(rest_toks);
//  //  (Some(a), rest)
//  //} else {
//  //  (None, rest_toks)
//  //}
//  //let type_name = TypeName::{
//  //  specifiers,
//  //  abstract_declarator
//  //}
//  //(type_name, rest_toks)
//}
//
//
////abstractDeclarator
////    : pointer
////    | pointer? directAbstractDeclarator gccDeclaratorExtension*
////    ;
//struct AbstractDeclarator {
//  pointer: Pointer?
//  directAbstractDeclarator: DirectAbstractDeclarator?
//} derive(Show, Eq)
//
////fn AbstractDeclarator::parse(toks: ArrayView[Token]) -> (AbstractDeclarator, ArrayView[Token]) raise {
////  match toks {
////    [Star, ..] => {
////      let (pointer, rest_toks) = Pointer::parse(toks);
////      let (direct_abstract_declarator, rest_toks) = DirectAbstractDeclarator::parse(rest_toks);
////      let abstract_declarator = AbstractDeclarator::{
////        pointer: Some(pointer),
////        directAbstractDeclarator: direct_abstract_declarator
////      }
////      (abstract_declarator, rest_toks)
////    }
////    [LParen | LBracket, ..] as toks => {
////      let (direct_abstract_declarator, rest_toks) = DirectAbstractDeclarator::parse(toks);
////      let abstract_declarator = AbstractDeclarator::{
////        pointer: None,
////        directAbstractDeclarator: direct_abstract_declarator
////      }
////      (abstract_declarator, rest_toks)
////    }
////    _ => raise ParseError("Expected pointer or direct abstract declarator")
////  }
////}
//
////
////directAbstractDeclarator
////    : '(' abstractDeclarator ')' gccDeclaratorExtension*
////    | '[' typeQualifierList? assignmentExpression? ']'
////    | '[' 'static' typeQualifierList? assignmentExpression ']'
////    | '[' typeQualifierList 'static' assignmentExpression ']'
////    | '[' '*' ']'
////    | '(' parameterTypeList? ')' gccDeclaratorExtension*
////    | directAbstractDeclarator '[' typeQualifierList? assignmentExpression? ']'
////    | directAbstractDeclarator '[' 'static' typeQualifierList? assignmentExpression ']'
////    | directAbstractDeclarator '[' typeQualifierList 'static' assignmentExpression ']'
////    | directAbstractDeclarator '[' '*' ']'
////    | directAbstractDeclarator '(' parameterTypeList? ')' gccDeclaratorExtension*
////    ;
//enum DirectAbstractDeclarator {
//  Array(Array[TypeQualifier], AssignExpr?)
//  StaticArray(Array[TypeQualifier], AssignExpr)
//  ArrayStatic(Array[TypeQualifier], AssignExpr)
//  StarArray
//  //FuncPtr(Array[ParameterDecl])
//} derive(Show, Eq)
//
//// TODO: Not Correct Implementation
//fn DirectAbstractDeclarator::parse(toks: ArrayView[Token]) -> (DirectAbstractDeclarator?, ArrayView[Token]) {
//  (None, toks)
//}
//
////test "TypeName Parsing Test" {
////  let code_expect_rest: Map[String, ArrayView[Token]] = {
////    "int *ptr" : [Identifier("ptr"), EOF],
////    "char **str" : [Identifier("str"), EOF],
////    "const char ** msg" : [Identifier("msg"), EOF],
////    "int const * arr" : [Identifier("arr"), EOF],
////    "int * const arr" : [Identifier("arr"), EOF],
////  }
////
////  for code, expect_rest in code_expect_rest {
////    let toks = lex(code)
////    let (_, rest_toks) = TypeName::parse(toks);
////    assert_eq(rest_toks, expect_rest)
////  }
////}
////
//////statement
//////    : labeledStatement
//////    | compoundStatement
//////    | expressionStatement
//////    | selectionStatement
//////    | iterationStatement
//////    | jumpStatement
//////    | ('__asm' | '__asm__') ('volatile' | '__volatile__') '(' (
//////        logicalOrExpression (',' logicalOrExpression)*
//////    )? (':' (logicalOrExpression (',' logicalOrExpression)*)?)* ')' ';'
//////    ;
////enum Statement {
////  LabeledStatement(LabeledStatement)
////  CompoundStatement(Array[BlockItem])
////  ExpressionStatement(Expr?)
////  SelectionStatement(SelectionStatement)
////  IterationStatement(IterationStatement)
////  JumpStatement(JumpStatement)
////  // Asm
////  // volatile
////} derive(Show, Eq)
////
//////labeledStatement
//////    : Identifier ':' statement?
//////    | 'case' constantExpression ':' statement
//////    | 'default' ':' statement
//////    ;
////enum LabeledStatement {
////  Label(String, Statement)
////  Case(ConstantExpr, Statement)
////  Default(Statement)
////} derive(Show, Eq)
////
////enum BlockItem {
////  Statement(Statement)
////  Declaration(Declaration)
////} derive(Show, Eq)
////
////enum SelectionStatement {
////  If(Expr, Statement, Statement?)
////  Switch(Expr, Statement)
////} derive(Show, Eq)
////
////enum IterationStatement {
////  While(Expr, Statement)
////  DoWhile(Statement, Expr)
////  For(ForCondition, Statement)
////} derive(Show, Eq)
////
//////forCondition
//////    : (forDeclaration | expression?) ';' forExpression? ';' forExpression?
//////    ;
////struct ForCondition {
////  init: ForInit?
////  cond: Array[AssignExpr]
////  inc: Array[AssignExpr]
////} derive(Show, Eq)
////
////struct ForInit {
////  decl: Array[Declaration]
////  initDecl: Array[InitDeclarator]
////} derive(Show, Eq)
////
////enum JumpStatement {
////  Goto(String)
////  Continue
////  Break
////  Return(Expr?)
////} derive(Show, Eq)
////
////struct CompilationUnit {
////  externalDeclatyons: Array[ExternalDeclaration]
////} derive(Show, Eq)
////
////enum ExternalDeclaration {
////  FunctionDefinition(FunctionDefinition)
////  Declaration(Declaration)
////} derive(Show, Eq)
////
////struct FunctionDefinition {
////  declSpecs: Array[DeclSpec]
////  declarator: Declarator
////  declarations: Array[Declaration]
////  body: Array[BlockItem]
////} derive(Show, Eq)
////
////
//////parameterTypeList
//////    : parameterList (',' '...')?
//////    ;
////
////struct ParameterTypeList {
////  params: Array[ParameterDecl]
////  variadic: Bool
////} derive(Show, Eq)
////
////fn ParameterTypeList::parse(toks: ArrayView[Token]) -> (ParameterTypeList, ArrayView[Token]) raise {
////  let (params, rest_toks) = ParameterList::parse(toks);
////  let params = params.inner()
////  match rest_toks {
////    [Comma, Ellipsis, .. rest_toks] => {
////      let param_type_list = ParameterTypeList::{ params, variadic: true }
////      (param_type_list, rest_toks)
////    }
////    _ => {
////      let param_type_list = ParameterTypeList::{ params, variadic: false }
////      (param_type_list, rest_toks)
////    }
////  }
////}
////
//////parameterList
//////    : parameterDeclaration (',' parameterDeclaration)*
//////    ;
////
////type ParameterList Array[ParameterDecl] derive(Show, Eq)
////
////fn ParameterList::parse(toks: ArrayView[Token]) -> (ParameterList, ArrayView[Token]) raise {
////  let decls: Array[ParameterDecl] = Array::new()
////  let (first_decl, rest_toks) = ParameterDecl::parse(toks);
////  decls.push(first_decl)
////  let rest_toks = loop rest_toks {
////    [Comma, .. rest_toks] => {
////      let (next_decl, rest) = ParameterDecl::parse(rest_toks);
////      decls.push(next_decl)
////      continue rest
////    }
////    toks => break toks
////  }
////  let param_list = ParameterList(decls)
////  (param_list, rest_toks)
////}
////
////
//////parameterDeclaration
//////    : declarationSpecifiers (declarator | abstractDeclarator)
//////    ;
////struct ParameterDecl {
////  declspecs: Array[DeclSpec]
////  declarator: ParamDeclarator
////} derive(Show, Eq)
////
////fn ParameterDecl::parse(toks: ArrayView[Token]) -> (ParameterDecl, ArrayView[Token]) raise {
////  let (decl_specs, rest_toks) = DeclSpecList::parse(toks);
////  let decl_specs = decl_specs.inner()
////  guard decl_specs.length() > 0 else {
////    raise ParseError("Parameter declaration must have at least one declaration specifier")
////  }
////  let (declarator, rest_toks) = ParamDeclarator::parse(rest_toks);
////  let param_decl = ParameterDecl::{
////    declspecs: decl_specs,
////    declarator
////  }
////  (param_decl, rest_toks)
////}
////
////enum ParamDeclarator {
////  Declarator(Declarator)
////  AbstractDeclarator(AbstractDeclarator)
////} derive(Show, Eq)
////
////fn ParamDeclarator::parse(toks: ArrayView[Token]) -> (ParamDeclarator, ArrayView[Token]) raise {
////  if (try? Declarator::parse(toks)) is Ok((declarator, rest_toks)) && rest_toks is [Comma | RParen, ..] {
////    (ParamDeclarator::Declarator(declarator), rest_toks)
////  } else if (try? AbstractDeclarator::parse(toks)) is Ok((abstract_declarator, rest_toks)) && rest_toks is [Comma | RParen, ..] {
////    (ParamDeclarator::AbstractDeclarator(abstract_declarator), rest_toks)
////  } else {
////    raise ParseError("Expected declarator or abstract declarator in parameter declaration")
////  }
////}
