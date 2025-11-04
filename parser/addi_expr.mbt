///|
///
/// Additive Expression
///
/// Additive expressions are binary expressions that perform
/// addition or subtraction operations on multiplicative expressions.
///
/// ## Examples
///
/// ```c
/// a + b;       // Addition
/// x - y;       // Subtraction
/// a + b - c;   // Multiple operations (left-associative)
/// 10 + 20;     // With literals
/// ```
///
/// ## Grammar (EBNF)
///
/// additive_expression
///   : multiplicative_expression
///   | additive_expression '+' multiplicative_expression
///   | additive_expression '-' multiplicative_expression
///   ;
///
/// ## Parse Function
///
/// ```mbt skip
/// fn Context::parse_addi_expr(
///   self: Context,
///   tokens: ArrayView[Token]
/// ) -> (AddiExpr, ArrayView[Token]) raise ParseError
/// ```
pub struct AddiExpr {
  kind : AddiExprKind
  ctype : CType
  tokens : ArrayView[Token]
}

///|
pub impl Eq for AddiExpr with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for AddiExpr with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
///
/// print like:
///
/// ```plaintext
/// additive expr: \{op} \{ctype}
/// `\{left}
/// `\{right}
/// ```
pub fn AddiExpr::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    MultiExpr(multi_expr) => multi_expr.to_string(color~)
    AddExpr(left, right) | SubExpr(left, right) => {
      let op = match self.kind {
        AddExpr(_, _) => "+"
        SubExpr(_, _) => "-"
        _ => ""
      }
      let prefix = if color {
        @color.taint("additive expr: \{op} ", Magenta) +
        @color.taint("(\{self.ctype})", Green)
      } else {
        "additive expr: \{op} " + "(\{self.ctype})"
      }
      let left_str = left.to_string(color~)
      let right_str = right.to_string(color~)
      // Add backtick prefix to each line of nested expressions
      let left_lines = left_str.split("\n")
      let left_formatted = left_lines.map(fn(line) { "`\{line}" }).join("\n")
      let right_lines = right_str.split("\n")
      let right_formatted = right_lines.map(fn(line) { "`\{line}" }).join("\n")
      "\{prefix}\n\{left_formatted}\n\{right_formatted}"
    }
  }
}

///|
pub enum AddiExprKind {
  MultiExpr(MultiExpr)
  AddExpr(AddiExpr, MultiExpr)
  SubExpr(AddiExpr, MultiExpr)
} derive(Eq)

///|
/// Parse an additive expression from the given tokens.
///
/// Returns a tuple containing the parsed AddiExpr and the remaining tokens.
///
/// ## Example Parse:
///
/// ```c
/// a + b;       // Addition
/// x - y;       // Subtraction
/// a + b - c;   // Multiple operations (left-associative)
/// 10 + 20;     // With literals
/// ```
///
/// ## Example Usage
///
/// ```mbt
/// let code = "x + y"
/// let ctx = Context::new(code~, source_file="demo")
/// ctx.add_var("x", CType::int())
/// ctx.add_var("y", CType::int())
/// let (addi_expr, rest) = ctx.parse_addi_expr(ctx.tokens)
/// inspect(
///   addi_expr.to_string(color=false),
///   content=(
///     
///   #|additive expr: + (int)
/// #|`variable x (int)
/// #|`variable y (int)
/// 
///   )
/// )
/// assert_true(rest is [{ kind: EOF, ..}])
/// ```
///
/// ## Raises
///
/// Parser will raise ParseError if:
///
/// 1. Parse multiplicative expression fails.
///
///    e.g.,
///
///    ```c
///    + 10  // invalid multiplicative expression before '+'
///    ```
///
/// 2. The operand type is not compatible with the additive operator.
///
///    e.g.,
///    ```c
///    struct Point { int x; int y; };
///    struct Point p1, p2;
///    p1 + p2;  // Invalid use of '+' operator on struct types
///    ```
pub fn Context::parse_addi_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (AddiExpr, ArrayView[Token]) raise ParseError {
  let init_toks = tokens
  let start_offset = tokens.start_offset()
  let (first_multi_expr, rest) = self.parse_multi_expr(tokens)
  let mut addi_expr = AddiExpr::{
    kind: MultiExpr(first_multi_expr),
    ctype: first_multi_expr.ctype,
    tokens: first_multi_expr.tokens,
  }
  let rest = loop rest {
    [{ kind: Operator("+"), .. }, .. rest] => {
      let (right_multi_expr, rest) = self.parse_multi_expr(rest)
      // TODO: Type checking for addition operator
      let ctype = addi_expr.ctype
      addi_expr = AddiExpr::{
        kind: AddExpr(addi_expr, right_multi_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    [{ kind: Operator("-"), .. }, .. rest] => {
      let (right_multi_expr, rest) = self.parse_multi_expr(rest)
      // TODO: Type checking for subtraction operator
      let ctype = addi_expr.ctype
      addi_expr = AddiExpr::{
        kind: SubExpr(addi_expr, right_multi_expr),
        ctype,
        tokens: init_toks[0:rest.start_offset() - start_offset],
      }
      continue rest
    }
    tokens => break tokens
  }
  (addi_expr, rest)
}
