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
/// ```c
/// arr[2];      // Array access
/// foo(10, 20); // Function call
/// point.x;     // Member access
/// point->y;    // Pointer member access
/// counter++;   // Post-increment
/// counter--;   // Post-decrement
/// ```
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
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_postfix_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (PostfixExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct PostfixExpr {
  kind : PostfixExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for PostfixExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for PostfixExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn PostfixExpr::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = match self.kind {
    PrimExpr(_) => ""
    MemberAccess(_) => "member access :"
    PtrMemberAccess(_) => "pointer member access :"
    PostInc(_) => "unary operator ++"
    PostDec(_) => "unary operator --"
  }
  let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
  let ctype = if color {
    @color.taint("(\{self.ctype})", Green)
  } else {
    "(\{self.ctype})"
  }
  let s = match self.kind {
    PrimExpr(prim_expr) => prim_expr.to_string(color~)
    MemberAccess(inner_expr, name) => {
      let inner_expr_str = inner_expr.to_string(color~)
      "\{prefix} .\{name} \{ctype}\n" + "└-\{inner_expr_str}"
    }
    PtrMemberAccess(inner_expr, name) => {
      let inner_expr_str = inner_expr.to_string(color~)
      "\{prefix} ->\{name} \{ctype}\n" + "└-\{inner_expr_str}"
    }
    PostInc(inner_expr) => {
      let inner_expr_str = inner_expr.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_expr_str}"
    }
    PostDec(inner_expr) => {
      let inner_expr_str = inner_expr.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_expr_str}"
    }
  }
  s
}

///|
pub enum PostfixExprKind {
  PrimExpr(PrimExpr)
  // ArrayAccess(PostfixExpr, Expr)
  // FuncCall(PostfixExpr, Array[AssignExpr])
  MemberAccess(PostfixExpr, String) // IDENTIFIER token
  PtrMemberAccess(PostfixExpr, String) // IDENTIFIER token
  PostInc(PostfixExpr)
  PostDec(PostfixExpr)
  // TypeInit(TypeName, Array[Initializer])
} derive(Eq)

///|
/// Parse a postfix expression from the given tokens.
///
/// Returns a tuple containing the parsed PostfixExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// arr[2];      // Array access
/// foo(10, 20); // Function call
/// point.x;     // Member access
/// point->y;    // Pointer member access
/// counter++;   // Post-increment
/// counter--;   // Post-decrement
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "i++"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("i", CType::int())
/// let (postfix_expr, rest) = ctx.parse_postfix_expr(ctx.tokens)
/// inspect(
///   postfix_expr.to_string(color=false),
///   content=(
///   
///   #|unary operator ++ (int)
/// #|└-variable i (int)
/// 
/// )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. parse primary expression in the beginning fails.
///
///    e.g.,
///    
///    ```c
///    ?++ // invalid primary expression
///    ```
///
/// 2. member access (.) is used on a type that does not have the specified field.
///
///    e.g.,
///
///    ```c
///    struct Point { int x; int y; };
///    struct Point p;
///    p.z; // 'Point' has no field named 'z'
///    ```
///
/// 3. pointer member access (->) is used on a type that
///    does not have the specified field.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point *p2;
///    p2->z; // 'Point' has no field named 'z'
///    ```
///
/// 4. post-increment (++) is used on a type that cannot be incremented.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p;
///    p++; // 'Point' cannot be used with '++' operator
///    ```
///
/// 5. post-decrement (--) is used on a type that cannot be decremented.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p;
///    p--; // 'Point' cannot be used with '--' operator
///    ```
pub fn Context::parse_postfix_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (PostfixExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (prim_expr, rest) = self.parse_prim_expr(tokens)
  let mut postfix_expr = PostfixExpr::{
    kind: PrimExpr(prim_expr),
    ctype: prim_expr.ctype,
    tokens: prim_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Dot, .. }, { kind: Identifier(name), .. }, .. rest] as tokens => {
      guard postfix_expr.ctype.get_field_ctype_by_dot_acc(name)
        is Some(field_ctype) else {
        raise ParseError(tokens[1], "Type has no field named '\{name}'")
      }
      postfix_expr = PostfixExpr::{
        kind: MemberAccess(postfix_expr, name),
        ctype: field_ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Arrow, .. }, { kind: Identifier(name), .. }, .. rest] => {
      guard postfix_expr.ctype.get_field_ctype_by_ptr_acc(name)
        is Some(field_ctype) else {
        raise ParseError(tokens[1], "Type has no field named '\{name}'")
      }
      postfix_expr = PostfixExpr::{
        kind: PtrMemberAccess(postfix_expr, name),
        ctype: field_ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("++"), .. }, .. rest] => {
      guard postfix_expr.ctype.is_inc_ok() else {
        raise ParseError(
          tokens[0],
          "Type '\{postfix_expr.ctype}' cannot be used with '++' operator",
        )
      }
      postfix_expr = PostfixExpr::{
        kind: PostInc(postfix_expr),
        ctype: postfix_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("--"), .. }, .. rest] => {
      guard postfix_expr.ctype.is_dec_ok() else {
        raise ParseError(
          tokens[0],
          "Type '\{postfix_expr.ctype}' cannot be used with '--' operator",
        )
      }
      postfix_expr = PostfixExpr::{
        kind: PostDec(postfix_expr),
        ctype: postfix_expr.ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (postfix_expr, rest)
}

///|
pub fn PostfixExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    PrimExpr(prim_expr) => prim_expr.is_constant()
    _ => false
  }
}

///|
pub fn PostfixExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    PrimExpr(prim_expr) => prim_expr.eval_as_int()
    _ => {
      let msg = "Cannot evaluate PostfixExpr as int: not a constant expression"
      raise ParseError(self.tokens[0], msg)
    }
  }
}

///|
pub fn PostfixExpr::is_assignable(self : Self) -> Bool {
  ignore(self)
  println(
    "PostfixExpr::is_assignable is not implemented yet, function defined in postfix_expr.mbt",
  )
  panic()
}

///|
test "Postfix Expr Parse Test" {
  let color = false
  let code =
    #|p.x ; p2->y ; i++ ; j-- ;
    #|p.z ; p2->zz ; p++ ; p-- ;
  let ctx = Context::new(code~, source_file="demo")
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  let point_ptr = point_struct.ptr_to()
  ctx.add_var("p", point_struct)
  ctx.add_var("p2", point_ptr)
  ctx.add_var("i", CType::int())
  ctx.add_var("j", CType::int())

  // Parse `p.x`
  let (postfix_expr, rest) = ctx.parse_postfix_expr(ctx.tokens)
  inspect(
    postfix_expr.to_string(color~),
    content=(
      #|member access : .x (int)
      #|└-variable p (struct Point)
    ),
  )
  assert_true(
    ctx.parse_postfix_expr(postfix_expr.tokens) is (re_postfix_expr, re_rest) &&
    re_postfix_expr == postfix_expr &&
    re_rest is [],
  )

  // Parse `p2->y`
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(
    postfix_expr.to_string(color~),
    content=(
      #|pointer member access : ->y (int)
      #|└-variable p2 (struct Point *)
    ),
  )
  assert_true(
    ctx.parse_postfix_expr(postfix_expr.tokens) is (re_postfix_expr, re_rest) &&
    re_postfix_expr == postfix_expr &&
    re_rest is [],
  )

  // Parse `i++`
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(
    postfix_expr.to_string(color~),
    content=(
      #|unary operator ++ (int)
      #|└-variable i (int)
    ),
  )
  assert_true(
    ctx.parse_postfix_expr(postfix_expr.tokens) is (re_postfix_expr, re_rest) &&
    re_postfix_expr == postfix_expr &&
    re_rest is [],
  )

  // Parse `j--`
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(
    postfix_expr.to_string(color~),
    content=(
      #|unary operator -- (int)
      #|└-variable j (int)
    ),
  )
  assert_true(
    ctx.parse_postfix_expr(postfix_expr.tokens) is (re_postfix_expr, re_rest) &&
    re_postfix_expr == postfix_expr &&
    re_rest is [],
  )

  // Parse `p.z`
  let rest = next_check_point(rest)
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

///|
test "Postfix Expr Error Test" {
  // Error test: member access on type without field
  let code_err1 = "p.z"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1.add_var("p", point_struct)
  let r = try? ctx_err1.parse_postfix_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: pointer member access on type without field
  let code_err2 = "p2->z"
  let ctx_err2 = Context::new(code=code_err2)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  let point_ptr = point_struct.ptr_to()
  ctx_err2.add_var("p2", point_ptr)
  let r = try? ctx_err2.parse_postfix_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: post-increment on struct type
  let code_err3 = "p++"
  let ctx_err3 = Context::new(code=code_err3)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err3.add_var("p", point_struct)
  let r = try? ctx_err3.parse_postfix_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: post-decrement on struct type
  let code_err4 = "p--"
  let ctx_err4 = Context::new(code=code_err4)
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err4.add_var("p", point_struct)
  let r = try? ctx_err4.parse_postfix_expr(ctx_err4.tokens)
  assert_true(r is Err(_))
}

///|
test "PostfixExpr Constant Eval Test" {
  // Test eval_as_int for postfix expressions
  let code =
    #|42 ; 100l ; 200u ; 
    #|x ; i++ ; j-- ; p.x ; p2->y ;
  let ctx = Context::new(code~, source_file="demo")
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  let point_ptr = point_struct.ptr_to()
  ctx.add_var("x", CType::int())
  ctx.add_var("i", CType::int())
  ctx.add_var("j", CType::int())
  ctx.add_var("p", point_struct)
  ctx.add_var("p2", point_ptr)

  // Parse and eval `42` (int literal wrapped in PostfixExpr)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(ctx.tokens)
  inspect(postfix_expr.eval_as_int(), content="42")
  assert_true(postfix_expr.is_constant())

  // Parse and eval `100l` (long literal wrapped in PostfixExpr)
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(postfix_expr.eval_as_int(), content="100")
  assert_true(postfix_expr.is_constant())

  // Parse and eval `200u` (unsigned int literal wrapped in PostfixExpr)
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  inspect(postfix_expr.eval_as_int(), content="200")
  assert_true(postfix_expr.is_constant())

  // Error test: variable is not constant
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  assert_false(postfix_expr.is_constant())
  let r = try? postfix_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: post-increment is not constant
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  assert_false(postfix_expr.is_constant())
  let r = try? postfix_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: post-decrement is not constant
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  assert_false(postfix_expr.is_constant())
  let r = try? postfix_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: member access is not constant
  let rest = next_check_point(rest)
  let (postfix_expr, rest) = ctx.parse_postfix_expr(rest)
  assert_false(postfix_expr.is_constant())
  let r = try? postfix_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: pointer member access is not constant
  let rest = next_check_point(rest)
  let (postfix_expr, _rest) = ctx.parse_postfix_expr(rest)
  assert_false(postfix_expr.is_constant())
  let r = try? postfix_expr.eval_as_int()
  assert_true(r is Err(_))
}
