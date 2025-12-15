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
///   | "sizeof" unary_expression
///   | "sizeof" '(' type_name ')'
///   | "alignof" '(' type_name ')'
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
    SizeofExpr(_) => "sizeof expression"
    SizeofType(_) => "sizeof type"
    Alignof(_) => "alignof"
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
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    PreDec(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    AddrOf(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    Deref(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    Negate(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    BitNot(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    LogicalNot(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    SizeofExpr(inner) => {
      let inner_str = inner.to_string(color~)
      let lines = inner_str.split("\n")
      let lines_formatted = format_lines(
        lines,
        head_with="└-",
        continue_with="   ",
      )
      "\{prefix} \{ctype}\n" + "\{lines_formatted}"
    }
    SizeofType(ctype) => {
      let type_str = if color {
        @color.taint("\{ctype}", Green)
      } else {
        "\{ctype}"
      }
      "\{prefix} \{ctype}\n└-type name: \{type_str}"
    }
    Alignof(ctype) => {
      let type_str = if color {
        @color.taint("\{ctype}", Green)
      } else {
        "\{ctype}"
      }
      "\{prefix} \{ctype}\n└-type name: \{type_str}"
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
  SizeofExpr(UnaryExpr)
  SizeofType(CType)
  Alignof(CType)
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
    // Sizeof '(' type_name ')'
    [{ kind: Keyword(Sizeof), .. }, { kind: Bracket('('), .. }, tok, ..] as tokens if self.is_keyword_or_type_name(
        tok,
      ) => {
      let (ctype, rest) = self.parse_type_name(tokens[2:])
      guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
        let msg = "Expected ')' after type name in sizeof"
        raise ParseError(rest[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: SizeofType(ctype),
        ctype: CType::long(),
        tokens,
      }
      (unary_expr, rest[1:])
    }
    // Size of unary_expr 
    [{ kind: Keyword(Sizeof), .. }, .. rest] => {
      let (inner_expr, rest) = self.parse_unary_expr(rest)
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: SizeofExpr(inner_expr),
        ctype: CType::long(),
        tokens,
      }
      (unary_expr, rest)
    }
    // align of '(' type_name ')'
    [{ kind: Keyword(Alignof), .. }, .. rest] => {
      guard rest is [{ kind: Bracket('('), .. }, .. rest] else {
        let msg = "Expected '(' after 'alignof'"
        raise ParseError(rest[0], msg)
      }
      let (ctype, rest) = self.parse_type_name(rest)
      guard rest is [{ kind: Bracket(')'), .. }, .. rest] else {
        let msg = "Expected ')' after type name in alignof"
        raise ParseError(rest[0], msg)
      }
      let tokens = init_toks[0:rest.start_offset() - start_offset]
      let unary_expr = UnaryExpr::{
        kind: Alignof(ctype),
        ctype: CType::long(),
        tokens,
      }
      (unary_expr, rest[1:])
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
pub fn UnaryExpr::is_constant(self : Self) -> Bool {
  match self.kind {
    PostfixExpr(postfix_expr) => postfix_expr.is_constant()
    PreInc(_) => false
    PreDec(_) => false
    AddrOf(_) => false
    Deref(_) => false
    Negate(inner) => inner.is_constant()
    BitNot(inner) => inner.is_constant()
    LogicalNot(inner) => inner.is_constant()
    // TODO: Check sizeof and alignof if their operands are constant
    SizeofExpr(_) => false
    SizeofType(_) => false
    Alignof(_) => false
  }
}

///|
pub fn UnaryExpr::eval_as_int(self : Self) -> Int raise ParseError {
  match self.kind {
    PostfixExpr(postfix_expr) => postfix_expr.eval_as_int()
    Negate(inner) => -inner.eval_as_int()
    BitNot(inner) => inner.eval_as_int().lnot()
    LogicalNot(inner) => {
      let val = inner.eval_as_int()
      (val == 0).to_int()
    }
    _ => {
      let msg = "Cannot evaluate unary expression as int"
      raise ParseError(self.tokens[0], msg)
    }
  }
}

///|
pub fn UnaryExpr::eval_as_double(self : Self) -> Double raise ParseError {
  match self.kind {
    PostfixExpr(postfix_expr) => postfix_expr.eval_as_double()
    Negate(inner) => -inner.eval_as_double()
    _ => {
      let msg = "Cannot evaluate unary expression as double"
      raise ParseError(self.tokens[0], msg)
    }
  }
}

///|
pub fn UnaryExpr::is_assignable(self : Self) -> Bool {
  match self.kind {
    PostfixExpr(postfix_expr) => postfix_expr.is_assignable()
    Deref(_) => !self.ctype.is_const
    PreInc(_) | PreDec(_) => false
    AddrOf(_) | Negate(_) | BitNot(_) | LogicalNot(_) => false
    SizeofExpr(_) | SizeofType(_) | Alignof(_) => false
  }
}

///|
test "Unary Expr Parse Test" {
  let color = false
  let code =
    #|++x ; --y ; *p ; -x ; ~f; !cond ; ++point; --point2;
    #|++(x) ; --(y) ; *(p++) ; -(x + 1) ; ~(f + 5) ; !(cond) ;
    #|~point; !point2;
  let ctx = Context::new(code~, source_file="demo")

  // Preludes
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
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

  // Parse `--y`
  let rest = next_check_point(rest)
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
  let rest = next_check_point(rest)
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
  let rest = next_check_point(rest)
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
  let rest = next_check_point(rest)
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
  let rest = next_check_point(rest)
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
  let rest = next_check_point(rest)
  assert_true(rest[0].kind is Operator("++"))
  let r = try? ctx.parse_unary_expr(rest)
  assert_true(r is Err(_))

  // Parse `--point2` (Should raise error)
  let rest = next_check_point(rest)
  assert_true(rest[0].kind is Operator("--"))
  let r = try? ctx.parse_unary_expr(rest)
  assert_true(r is Err(_))

  // Parse `++(x)` - pre-increment with parenthesized variable
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
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

  // Parse `--(y)` - pre-decrement with parenthesized variable
  let rest = next_check_point(rest)
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

  // Parse `*(p)` - dereference with parenthesized pointer
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator * (int)
      #|└-unary operator ++ (int *)
      #|   └-variable p (int *)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `-(x)` - negation with parenthesized variable
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator - (int)
      #|└-additive expr: + (int)
      #|   ├-variable x (int)
      #|   └-int literal 1 (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `~(f)` - bitwise NOT with parenthesized variable
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(
    unary_expr.to_string(color~),
    content=(
      #|unary operator ~ (int)
      #|└-additive expr: + (int)
      #|   ├-variable f (int)
      #|   └-int literal 5 (int)
    ),
  )
  assert_true(
    ctx.parse_unary_expr(unary_expr.tokens) is (re_unary_expr, re_rest) &&
    re_unary_expr == unary_expr &&
    re_rest is [],
  )

  // Parse `!(cond)` - logical NOT with parenthesized variable
  let rest = next_check_point(rest)
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

  // Skip to error tests section
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

///|
test "Unary Expr Error Test" {
  // Error test: pre-increment on struct type
  let code_err1 = "++p"
  let ctx_err1 = Context::new(code=code_err1)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err1.add_var("p", point_struct)
  let r = try? ctx_err1.parse_unary_expr(ctx_err1.tokens)
  assert_true(r is Err(_))

  // Error test: pre-decrement on struct type
  let code_err2 = "--p"
  let ctx_err2 = Context::new(code=code_err2)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err2.add_var("p", point_struct)
  let r = try? ctx_err2.parse_unary_expr(ctx_err2.tokens)
  assert_true(r is Err(_))

  // Error test: dereference on non-pointer type
  let code_err3 = "*x"
  let ctx_err3 = Context::new(code=code_err3)
  ctx_err3.add_var("x", CType::int())
  let r = try? ctx_err3.parse_unary_expr(ctx_err3.tokens)
  assert_true(r is Err(_))

  // Error test: negate on struct type
  let code_err4 = "-p"
  let ctx_err4 = Context::new(code=code_err4)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err4.add_var("p", point_struct)
  let r = try? ctx_err4.parse_unary_expr(ctx_err4.tokens)
  assert_true(r is Err(_))

  // Error test: bitwise NOT on struct type
  let code_err5 = "~p"
  let ctx_err5 = Context::new(code=code_err5)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err5.add_var("p", point_struct)
  let r = try? ctx_err5.parse_unary_expr(ctx_err5.tokens)
  assert_true(r is Err(_))

  // Error test: logical NOT on struct type
  let code_err6 = "!p"
  let ctx_err6 = Context::new(code=code_err6)
  let point_fields = [
    { name: "x", ctype: CType::int(), bit_width: None },
    { name: "y", ctype: CType::int(), bit_width: None },
  ]
  let point_struct = CType::struct_type("Point", point_fields)
  ctx_err6.add_var("p", point_struct)
  let r = try? ctx_err6.parse_unary_expr(ctx_err6.tokens)
  assert_true(r is Err(_))
}

///|
test "UnaryExpr Constant Eval Test" {
  // Test eval_as_int for unary expressions
  let code =
    #|42 ; -10 ; ~5 ; !0 ; !1 ; 
    #|-100 ; ~0 ; !!5 ; -~3 ;
    #|x ; ++y ; --z ; *p ; &i ;
  let ctx = Context::new(code~, source_file="demo")
  ctx.add_var("x", CType::int())
  ctx.add_var("y", CType::int())
  ctx.add_var("z", CType::int())
  ctx.add_var("p", CType::int().ptr_to())
  ctx.add_var("i", CType::int())

  // Parse and eval `42` (int literal wrapped in UnaryExpr)
  let (unary_expr, rest) = ctx.parse_unary_expr(ctx.tokens)
  inspect(unary_expr.eval_as_int(), content="42")
  assert_true(unary_expr.is_constant())

  // Parse and eval `-10` (negation)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="-10")
  assert_true(unary_expr.is_constant())

  // Parse and eval `~5` (bitwise NOT)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="-6")
  assert_true(unary_expr.is_constant())

  // Parse and eval `!0` (logical NOT of 0 = 1)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="1")
  assert_true(unary_expr.is_constant())

  // Parse and eval `!1` (logical NOT of 1 = 0)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="0")
  assert_true(unary_expr.is_constant())

  // Parse and eval `-100` (negation of larger number)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="-100")
  assert_true(unary_expr.is_constant())

  // Parse and eval `~0` (bitwise NOT of 0 = -1)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="-1")
  assert_true(unary_expr.is_constant())

  // Parse and eval `!!5` (double logical NOT: 5 -> 0 -> 1)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="1")
  assert_true(unary_expr.is_constant())

  // Parse and eval `-~3` (negation of bitwise NOT: ~3 = -4, then -(-4) = 4)
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  inspect(unary_expr.eval_as_int(), content="4")
  assert_true(unary_expr.is_constant())

  // Error test: variable is not constant
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  assert_false(unary_expr.is_constant())
  let r = try? unary_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: pre-increment is not constant
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  assert_false(unary_expr.is_constant())
  let r = try? unary_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: pre-decrement is not constant
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  assert_false(unary_expr.is_constant())
  let r = try? unary_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: dereference is not constant
  let rest = next_check_point(rest)
  let (unary_expr, rest) = ctx.parse_unary_expr(rest)
  assert_false(unary_expr.is_constant())
  let r = try? unary_expr.eval_as_int()
  assert_true(r is Err(_))

  // Error test: address-of is not constant
  let rest = next_check_point(rest)
  let (unary_expr, _rest) = ctx.parse_unary_expr(rest)
  assert_false(unary_expr.is_constant())
  let r = try? unary_expr.eval_as_int()
  assert_true(r is Err(_))
}
