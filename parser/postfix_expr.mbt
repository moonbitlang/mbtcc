///|
///
/// Postfix Expression
///
/// Postfix expressions are expressions that follow primary expressions 
/// and add additional functionality, such as array access, 
/// function calls, member access, and post-increment/decrement operations.
///
/// ## Examples
///
///
/// ## Grammar (EBNF)
///
/// postfix_expression
/// 	: primary_expression
/// 	| postfix_expression '[' expression ']'  (TODO)
/// 	| postfix_expression '('assign_expr_list? ')'  (TODO)
/// 	| postfix_expression '.' IDENTIFIER
/// 	| postfix_expression "->" IDENTIFIER
/// 	| postfix_expression "++"
/// 	| postfix_expression "--"
/// 	| '(' type_name ')' '{' initializer_list ','? '}' (TODO)
/// 	;
pub struct PostfixExpr {
  kind: PostfixExprKind
  ctype: CType
  tokens: ArrayView[Token]
}

pub fn PostfixExpr::to_string(self: Self, color~: Bool = true, indent~ : Int = 0) -> String {
  let prefix = match self.kind {
    PrimExpr(_) =>  ""
    MemberAccess(_) =>  "member access :"
    PtrMemberAccess(_) => "pointer member access :"
    PostInc(_) =>   "unary operator ++"
    PostDec(_) =>  "unary operator --"
  }
  let prefix = if color {
    @color.taint(prefix, Magenta)
  } else {
    prefix
  }
  let ctype = if color {
    @color.taint("(\{self.ctype})", Green)
  } else {
    "(\{self.ctype})"
  }
  let s = match self.kind {
    PrimExpr(prim_expr) => prim_expr.to_string(color=color)
    MemberAccess(inner_expr, name) => {
      let inner_expr_str = inner_expr.to_string(color~, indent~)
      "\{prefix} .\{name} \{ctype}\n" + "`\{inner_expr_str}"
    }
    PtrMemberAccess(inner_expr, name) => {
      let inner_expr_str = inner_expr.to_string(color~, indent~)
      "\{prefix} ->\{name} \{ctype}\n" + "`\{inner_expr_str}"
    }
    PostInc(inner_expr) => {
      let inner_expr_str = inner_expr.to_string(color~, indent~)
      "\{prefix} \{ctype}\n" + "`\{inner_expr_str}"
    }
    PostDec(inner_expr) => {
      let inner_expr_str = inner_expr.to_string(color~, indent~)
      "\{prefix} \{ctype}\n" + "`\{inner_expr_str}"
    }
  }
  " ".repeat(indent) + s
}

pub impl Show for PostfixExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

pub enum PostfixExprKind {
  PrimExpr(PrimExpr)
  // ArrayAccess(PostfixExpr, Expr)
  // FuncCall(PostfixExpr, Array[AssignExpr])
  MemberAccess(PostfixExpr, String) // IDENTIFIER token
  PtrMemberAccess(PostfixExpr, String) // IDENTIFIER token
  PostInc(PostfixExpr)
  PostDec(PostfixExpr)
  // TypeInit(TypeName, Array[Initializer])
}

pub fn Context::parse_postfix_expr(
  self: Context, 
  tokens: ArrayView[Token]
) -> (PostfixExpr, ArrayView[Token]) raise ParseError {
  let start_offset = tokens.start_offset()
  let (prim_expr, rest) = self.parse_prim_expr(tokens)
  let mut postfix_expr = PostfixExpr::{
    kind: PrimExpr(prim_expr),
    ctype: prim_expr.ctype,
    tokens: prim_expr.tokens
  }
  let rest = loop rest {
    [{ kind: Dot, .. }, { kind: Identifier(name), .. }, ..rest] as tokens => {
      guard postfix_expr.ctype.get_field_ctype_by_dot_acc(name) is Some(field_ctype) else {
        raise ParseError(tokens[1], "Type has no field named '\{name}'")
      }
      postfix_expr = PostfixExpr::{
        kind: MemberAccess(postfix_expr, name),
        ctype: field_ctype,
        tokens: tokens[0:(rest.start_offset() - start_offset)]
      }
      continue rest
    }
    [{ kind: Arrow, .. }, { kind: Identifier(name), .. }, ..rest] => {
      guard postfix_expr.ctype.get_field_ctype_by_ptr_acc(name) is Some(field_ctype) else {
        raise ParseError(tokens[1], "Type has no field named '\{name}'")
      }
      postfix_expr = PostfixExpr::{
        kind: PtrMemberAccess(postfix_expr, name),
        ctype: field_ctype,
        tokens: tokens[0:(rest.start_offset() - start_offset)]
      }
      continue rest
    }
    [{ kind: Operator("++"), .. }, ..rest] => {
      guard postfix_expr.ctype.is_inc_ok() else {
        raise ParseError(tokens[0], "Type '\{postfix_expr.ctype}' cannot be used with '++' operator")
      }
      postfix_expr = PostfixExpr::{
        kind: PostInc(postfix_expr),
        ctype: postfix_expr.ctype,
        tokens: tokens[0:(rest.start_offset() - start_offset)]
      }
      continue rest
    }
    [{ kind: Operator("--"), .. }, ..rest] => {
      guard postfix_expr.ctype.is_dec_ok() else {
        raise ParseError(tokens[0], "Type '\{postfix_expr.ctype}' cannot be used with '--' operator")
      }
      postfix_expr = PostfixExpr::{
        kind: PostDec(postfix_expr),
        ctype: postfix_expr.ctype,
        tokens: tokens[0:(rest.start_offset() - start_offset)]
      }
      continue rest
    }
    tokens => break tokens
  }
  (postfix_expr, rest)
}

test "Postfix Expr Parse Test" {
  let color = false
  let code =
    #|p.x p2->y i++ j--
    #|p.z ; p2->zz ; p++ ; p-- ;
  let ctx = Context::new(code~, source_file = "demo")
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  let point_ptr = point_struct.ptr_to()
  ctx.add_var("p", point_struct)
  ctx.add_var("p2", point_ptr)
  ctx.add_var("i", CType::int())
  ctx.add_var("j", CType::int())
  let (postfix_expr, rest) = ctx.parse_postfix_expr(ctx.tokens)
  inspect(postfix_expr.to_string(color~), content = (
    #|member access : .x (int)
    #|`variable p (struct Point)
  ))
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(postfix_expr.to_string(color~), content = (
    #|pointer member access : ->y (int)
    #|`variable p2 (struct Point *)
  ))
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(postfix_expr.to_string(color~), content = (
    #|unary operator ++ (int)
    #|`variable i (int)
  ))
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(postfix_expr.to_string(color~), content = (
    #|unary operator -- (int)
    #|`variable j (int)
  ))

  // Parse `p.z`
  let r = try? ctx.parse_postfix_expr(rest)
  assert_true(r is Err(_))

  // adust rest to skip invalid `p.z`
  let rest = next_check_point(rest)
  assert_true(rest[0].kind is Identifier("p2"))
  let r = try? ctx.parse_postfix_expr(rest)
  assert_true(r is Err(_))

  // adust rest to skip invalid `p2->zz`
  let rest = next_check_point(rest)
  assert_true(rest[0].kind is Identifier("p"))
  let r = try? ctx.parse_postfix_expr(rest)
  assert_true(r is Err(_))

  // adust rest to skip invalid `p++`
  let rest = next_check_point(rest)
  assert_true(rest[0].kind is Identifier("p"))
  let r = try? ctx.parse_postfix_expr(rest)
  assert_true(r is Err(_))
}
