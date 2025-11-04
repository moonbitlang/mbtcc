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
/// ## Grammar (EBNF)
///
/// unary_expression
///   : postfix_expression
///   | "++" unary_expression
///   | "--" unary_expression
///   | "&" cast_expression
///   | "*" cast_expression
///   | "-" cast_expression
///   | "~" cast_expression
///   | "!" cast_expression
///   | "sizeof" unary_expression          (TODO)
///   | "sizeof" '(' type_name ')'         (TODO)
///   | "alignof" '(' type_name ')'        (TODO)
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_unary_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (UnaryExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct UnaryExpr {
  kind : UnaryExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for UnaryExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for UnaryExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn UnaryExpr::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = match self.kind {
    PostfixExpr(_) => ""
    PreInc(_) => "unary operator ++"
    PreDec(_) => "unary operator --"
    AddrOf(_) => "unary operator &"
    Deref(_) => "unary operator *"
    Negate(_) => "unary operator -"
    BitNot(_) => "unary operator ~"
    LogicalNot(_) => "unary operator !"
  }
  let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
  let ctype = if color {
    @color.taint("(\{self.ctype})", Green)
  } else {
    "(\{self.ctype})"
  }
  let s = match self.kind {
    PostfixExpr(postfix_expr) => postfix_expr.to_string(color~)
    PreInc(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
    PreDec(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
    AddrOf(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
    Deref(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
    Negate(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
    BitNot(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
    LogicalNot(inner) => {
      let inner_str = inner.to_string(color~)
      "\{prefix} \{ctype}\n" + "└-\{inner_str}"
    }
  }
  s
}

///|
pub enum UnaryExprKind {
  PostfixExpr(PostfixExpr)
  PreInc(UnaryExpr)
  PreDec(UnaryExpr)
  AddrOf(UnaryExpr)
  Deref(UnaryExpr)
  Negate(UnaryExpr)
  BitNot(UnaryExpr)
  LogicalNot(UnaryExpr)
  // SizeofExpr(UnaryExpr)
  // SizeofType(CType)
  // Alignof(CType)
} derive(Eq)

///|
/// Parse an unary expression from the given tokens.
///
/// Return a tuple of the parsed `UnaryExpr` and the remaining tokens.
///
/// ## Example Parse
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
/// ## Example Usage
///
/// ```mbt
/// let code = "++i"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("i", CType::int())
/// let (unary_expr, rest) = ctx.parse_unary_expr(ctx.tokens)
/// inspect(
///   unary_expr.to_string(color=false),
///   content=(
///   
///   
///   #|unary operator ++ (int)
/// #|└-variable i (int)
/// 
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
/// 1. Parse postfix expression fails.
///
///    e.g.,
///    ```c
///    ++;  // Invalid postfix expression after '++'
///    ```
/// 2. The operand type is not compatible with the unary operator.
///
///   e.g.,
///   ```c
///   struct Point { int x; int y; };
///   struct Point p;
///   ++p;  // Invalid use of '++' operator on struct type
///   ```
///
/// 3. Dereferencing a non-pointer type.
///
///    e.g.,
///    ```c
///    int x = 10;
///    *x;  // Invalid dereference of non-pointer type
///    ```
pub fn Context::parse_unary_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (UnaryExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  match tokens {
    [{ kind: Operator("++"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_inc_ok() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with '++' operator"
        raise ParseError(rest[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: PreInc(inner_expr),
        ctype: inner_expr.ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("--"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_dec_ok() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with '--' operator"
        raise ParseError(rest[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: PreDec(inner_expr),
        ctype: inner_expr.ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    // TODO: Should parse cast expression, instead of unary expression
    // Address-of operator
    [{ kind: Operator("&"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      let addr_ctype = inner_expr.ctype.ptr_to()
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: AddrOf(inner_expr),
        ctype: addr_ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("*"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.dataKind is Ptr(deref_ctype) else {
        let msg = "Type '\{inner_expr.ctype}' cannot be dereferenced"
        raise ParseError(tokens[0], msg)
      }
      let tokens = tokens[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: Deref(inner_expr),
        ctype: deref_ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("-"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_numeric() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be negated"
        raise ParseError(tokens[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: Negate(inner_expr),
        ctype: inner_expr.ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("~"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_integral() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with bitwise NOT operator"
        raise ParseError(tokens[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: BitNot(inner_expr),
        ctype: inner_expr.ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    [{ kind: Operator("!"), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      guard inner_expr.ctype.is_integral() else {
        let msg = "Type '\{inner_expr.ctype}' cannot be used with logical NOT operator"
        raise ParseError(tokens[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: LogicalNot(inner_expr),
        ctype: inner_expr.ctype,
        tokens,
      }
      (unary_expr, rest)
    }
    tokens => {
      let (postfix_expr, rest) = self.parse_postfix_expr(tokens)
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: PostfixExpr(postfix_expr),
        ctype: postfix_expr.ctype,
        tokens,
      }
      (unary_expr, rest)
    }
  }
}

///|
test "Unary Expr Parse Test" {
  let color = false
  let code =
    #|++x ; --y ; *p ; -x ; ~f; !cond ; ++point; --point2;
    #|~point; !point2;
  let ctx = Context::new(code~, source_file="demo")

  // Preludes
  let point_fields = [("x", CType::int()), ("y", CType::int())]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())
  ctx.add_var("p", CType::int().ptr_to())
  ctx.add_var("f", CType::int())
  ctx.add_var("cond", CType::int())
  ctx.add_var("point", point_struct)
  ctx.add_var("point2", point_struct)

  // Parse `++x`
  let (unary_expr, rest) = ctx.parse_unary_expr(ctx.tokens)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator ++ (int)
      #|└-variable x (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )
  let rest = skip_semi(rest)

  // Parse `--y`
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator -- (int)
      #|└-variable y (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `*p`
  let rest = skip_semi(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator * (int)
      #|└-variable p (int *)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `-x`
  let rest = skip_semi(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator - (int)
      #|└-variable x (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `~f`
  let rest = skip_semi(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator ~ (int)
      #|└-variable f (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `!cond`
  let rest = skip_semi(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator ! (int)
      #|└-variable cond (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `++point` (Should raise error)
  let rest = skip_semi(rest)
  assert_true(rest[0].kind is Operator("++"))
  let r = try? ctx.parse_unary_expr(rest)
  assert_true(r is Err(_))

  // adjust rest to skip invalid `++point`
  let rest = next_check_point(rest)
  // Parse `--point2` (Should raise error)
  assert_true(rest[0].kind is Operator("--"))
  let r = try? ctx.parse_unary_expr(rest)
  assert_true(r is Err(_))

  // adjust rest to skip invalid `--point2`
  let rest = next_check_point(rest)
  // Parse `~point` (Should raise error)
  assert_true(rest[0].kind is Operator("~"))
  let r = try? ctx.parse_unary_expr(rest)
  assert_true(r is Err(_))

  // adjust rest to skip invalid `~point`
  let rest = next_check_point(rest)
  // Parse `!point2` (Should raise error)
  assert_true(rest[0].kind is Operator("!"))
  let r = try? ctx.parse_unary_expr(rest)
  assert_true(r is Err(_))
}
