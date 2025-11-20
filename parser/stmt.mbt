///|
pub struct Statement {
  kind : StmtKind
  tokens : ArrayView[Token]
}

///|
pub impl Eq for Statement with equal(self, other) {
  self.kind == other.kind
}

///|
pub impl Show for Statement with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn Statement::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    Labeled(label, stmt) => {
      let prefix = if color {
        @color.taint("labeled statement: ", Magenta) + label
      } else {
        "labeled statement: " + label
      }
      let stmt_str = stmt.to_string(color~)
      let stmt_lines = stmt_str.split("\n")
      let stmt_formatted = format_lines(
        stmt_lines,
        head_with="└-",
        continue_with="  ",
      )
      "\{prefix}\n\{stmt_formatted}"
    }
    Case(const_expr, stmt) => {
      let prefix = if color {
        @color.taint("case statement", Magenta)
      } else {
        "case statement"
      }
      let value_str = const_expr.to_string(color~)
      let stmt_str = stmt.to_string(color~)
      let value_lines = value_str.split("\n")
      let value_formatted = format_lines(
        value_lines,
        head_with="├-value: ",
        continue_with="│        ",
      )
      let stmt_lines = stmt_str.split("\n")
      let stmt_formatted = format_lines(
        stmt_lines,
        head_with="└-stmt: ",
        continue_with="        ",
      )
      "\{prefix}\n\{value_formatted}\n\{stmt_formatted}"
    }
    DefaultCase(stmt) => {
      let prefix = if color {
        @color.taint("default case statement", Magenta)
      } else {
        "default case statement"
      }
      let stmt_str = stmt.to_string(color~)
      let stmt_lines = stmt_str.split("\n")
      let stmt_formatted = format_lines(
        stmt_lines,
        head_with="└-stmt: ",
        continue_with="        ",
      )
      "\{prefix}\n\{stmt_formatted}"
    }
    Compound(compound_stmt) => compound_stmt.to_string(color~)
    Expr(expr) => {
      let prefix = if color {
        @color.taint("expr statement", Magenta)
      } else {
        "expr statement"
      }
      let expr_str = expr.to_string(color~)
      let expr_lines = expr_str.split("\n")
      let expr_formatted = format_lines(
        expr_lines,
        head_with="└-",
        continue_with="  ",
      )
      "\{prefix}\n\{expr_formatted}"
    }
    If(if_stmt) => if_stmt.to_string(color~)
    Switch(switch_stmt) => switch_stmt.to_string(color~)
    For(for_stmt) => for_stmt.to_string(color~)
    While(while_stmt) => while_stmt.to_string(color~)
    Goto(label) => {
      let prefix = if color {
        @color.taint("goto statement: ", Magenta) + label
      } else {
        "goto statement: " + label
      }
      prefix
    }
    Continue =>
      if color {
        @color.taint("continue statement", Magenta)
      } else {
        "continue statement"
      }
    Break =>
      if color {
        @color.taint("break statement", Magenta)
      } else {
        "break statement"
      }
    Return(expr) => {
      let prefix = if color {
        @color.taint("return statement", Magenta)
      } else {
        "return statement"
      }
      let expr_str = expr.to_string(color~)
      let expr_lines = expr_str.split("\n")
      let expr_formatted = format_lines(
        expr_lines,
        head_with="└-",
        continue_with="  ",
      )
      "\{prefix}\n\{expr_formatted}"
    }
    ReturnVoid =>
      if color {
        @color.taint("return statement (void)", Magenta)
      } else {
        "return statement (void)"
      }
    Noop =>
      if color {
        @color.taint("empty statement", Magenta)
      } else {
        "empty statement"
      }
  }
}

///|
pub enum StmtKind {
  // IDENTIFIER : statement
  Labeled(String, Statement)
  // CASE constant_expression : statement
  Case(ConstantExpr, Statement)
  // DEFAULT : statement
  DefaultCase(Statement)
  Compound(CompoundStmt)
  Expr(Expr)
  If(IfStmt)
  Switch(SwitchStmt)
  For(ForStmt)
  While(WhileStmt)
  Goto(String)
  Continue
  Break
  Return(Expr)
  ReturnVoid
  Noop
} derive(Eq)

///|
pub fn Context::parse_statement(
  self : Self,
  tokens : ArrayView[Token],
) -> (Statement, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let start_offset = init_tokens.start_offset()
  let (kind, rest) = match tokens {
    [{ kind: Bracket('{'), .. }, ..] => {
      let (compound_stmt, rest) = self.parse_compound_statement(tokens)
      (StmtKind::Compound(compound_stmt), rest)
    }
    [{ kind: Keyword(Return), .. }, { kind: Semi, .. }, .. rest] =>
      (StmtKind::ReturnVoid, rest)
    [{ kind: Keyword(Return), .. }, .. rest] => {
      let (expr, rest) = self.parse_expr(rest)
      guard rest is [{ kind: Semi, .. }, .. rest] else {
        raise ParseError(rest[0], "Expected ';' after return expression")
      }
      let stmt_kind = StmtKind::Return(expr)
      (stmt_kind, rest)
    }
    [{ kind: Keyword(Break), .. }, { kind: Semi, .. }, .. rest] =>
      (StmtKind::Break, rest)
    [{ kind: Keyword(Break), .. }, tok, ..] =>
      raise ParseError(tok, "Expected ';' after 'break'")
    [{ kind: Keyword(Continue), .. }, { kind: Semi, .. }, .. rest] =>
      (StmtKind::Continue, rest)
    [{ kind: Keyword(Continue), .. }, tok, ..] =>
      raise ParseError(tok, "Expected ';' after 'continue'")
    [
      { kind: Keyword(Goto), .. },
      { kind: Identifier(label), .. },
      { kind: Semi, .. },
      .. rest,
    ] if self.is_label(label) => (StmtKind::Goto(label), rest)
    [{ kind: Keyword(Goto), .. }, .. rest] =>
      raise ParseError(rest[0], "Expected label name after 'goto'")
    [{ kind: Semi, .. }, .. rest] => (StmtKind::Noop, rest)
    [{ kind: Keyword(If), .. }, ..] => {
      let (if_stmt, rest) = self.parse_if_statement(tokens)
      (StmtKind::If(if_stmt), rest)
    }
    [{ kind: Keyword(Switch), .. }, ..] => {
      let (switch_stmt, rest) = self.parse_switch_statement(tokens)
      (StmtKind::Switch(switch_stmt), rest)
    }
    [{ kind: Keyword(For), .. }, ..] => {
      let (for_stmt, rest) = self.parse_for_statement(tokens)
      (StmtKind::For(for_stmt), rest)
    }
    [{ kind: Keyword(While), .. }, ..] => {
      let (while_stmt, rest) = self.parse_while_statement(tokens)
      (StmtKind::While(while_stmt), rest)
    }
    [{ kind: Identifier(label), .. }, { kind: Colon, .. }, .. rest] if !self.is_name_has_been_defined(
        label,
      ) => {
      let (stmt, rest) = self.parse_statement(rest)
      (StmtKind::Labeled(label, stmt), rest)
    }
    [{ kind: Keyword(Case), .. }, .. rest] => {
      let (const_expr, rest) = self.parse_constant_expr(rest)
      guard rest is [{ kind: Colon, .. }, .. rest] else {
        raise ParseError(
          rest[0],
          "Expected ':' after 'case' constant expression",
        )
      }
      let (stmt, rest) = self.parse_statement(rest)
      (StmtKind::Case(const_expr, stmt), rest)
    }
    [{ kind: Keyword(Default), .. }, { kind: Colon, .. }, .. rest] => {
      let (stmt, rest) = self.parse_statement(rest)
      (StmtKind::DefaultCase(stmt), rest)
    }
    tokens => {
      let (expr, rest) = self.parse_expr(tokens)
      guard rest is [{ kind: Semi, .. }, .. rest] else {
        raise ParseError(rest[0], "Expected ';' after expression statement")
      }
      (StmtKind::Expr(expr), rest)
    }
  }
  let tokens = init_tokens[0:rest.start_offset() - start_offset]
  let stmt = Statement::{ kind, tokens }
  (stmt, rest)
}
