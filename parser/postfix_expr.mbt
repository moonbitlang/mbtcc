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

pub enum PostfixExprKind {
  PrimExpr(PrimExpr)
  // ArrayAccess(PostfixExpr, Expr)
  // FuncCall(PostfixExpr, Array[AssignExpr])
  MemberAccess(PostfixExprKind, String) // IDENTIFIER token
  PtrMemberAccess(PostfixExprKind, String) // IDENTIFIER token
  PostInc(PostfixExprKind)
  PostDec(PostfixExprKind)
  // TypeInit(TypeName, Array[Initializer])
}

pub fn Context::parse_postfix_expr(
  self: Context, 
  tokens: ArrayView[Token]
) -> (PostfixExpr, ArrayView[Token]) raise ParseError {
  let start_offset = tokens.start_offset()
  let (prim_expr, rest) = self.parse_prim_expr(tokens)
  let mut postfix_expr = PostfixExprKind::PrimExpr(prim_expr)
  let mut ctype = prim_expr.ctype
  let rest = loop rest {
    [{ kind: Dot, .. }, { kind: Identifier(name), .. }, ..rest] as tokens => {
      guard ctype.get_field_ctype_by_dot_acc(name) is Some(field_ctype) else {
        raise ParseError(tokens[1], "Type has no field named '{name}'")
      }
      ctype = field_ctype
      postfix_expr = PostfixExprKind::MemberAccess(postfix_expr, name)
      continue rest
    }
    [{ kind: Arrow, .. }, { kind: Identifier(name), .. }, ..rest] => {
      guard ctype.get_field_ctype_by_ptr_acc(name) is Some(field_ctype) else {
        raise ParseError(tokens[1], "Type has no field named '{name}'")
      }
      ctype = field_ctype
      postfix_expr = PostfixExprKind::PtrMemberAccess(postfix_expr, name)
      continue rest
    }
    [{ kind: Operator("++"), .. }, ..rest] => {
      postfix_expr = PostfixExprKind::PostInc(postfix_expr)
      continue rest
    }
    [{ kind: Operator("--"), .. }, ..rest] => {
      postfix_expr = PostfixExprKind::PostDec(postfix_expr)
      continue rest
    }
    tokens => break tokens
  }
  let end_offset = rest.start_offset()
  let offset_range = end_offset - start_offset
  let postfix_expr = PostfixExpr::{
    kind: postfix_expr,
    ctype: ctype,
    tokens: tokens[0:offset_range]
  }
  (postfix_expr, rest)
}
