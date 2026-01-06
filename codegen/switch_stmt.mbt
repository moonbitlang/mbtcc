///|
/// Switch Statement Code Generation
///
/// This module handles the LLVM IR generation for switch statements.
/// Switch statements in C are complex control flow structures that support
/// fall-through behavior between cases.

///|
/// Information about a case label in a switch statement
priv struct CaseInfo {
  value : Int64 // The constant value for this case
  bb : @IR.BasicBlock // The basic block for this case
}

///|
/// Emit a switch statement
///
/// This function generates LLVM IR for a switch statement, which involves:
/// 1. Collecting all case and default labels from the switch body
/// 2. Creating basic blocks for each case and the default case
/// 3. Generating the switch instruction
/// 4. Emitting code for each case with proper fall-through handling
pub fn Context::emit_switch_stmt(
  self : Context,
  switch_stmt : @parser.SwitchStmt,
) -> Unit raise {
  // Evaluate the switch condition
  let cond_value = self.emit_expr(switch_stmt.expr)

  // Convert condition to integer if needed
  let cond_int = self.convert_value_to_int_value(cond_value)

  // Get the current function
  let func = self.current_func.unwrap()

  // Create the merge block (after switch)
  let merge_bb = func.addBasicBlock()

  // Collect cases from the switch body
  let (cases, default_bb_opt) = self.collect_switch_cases(
    switch_stmt.body,
    func,
  )

  // If no default case, use merge block as default
  let default_bb = match default_bb_opt {
    Some(bb) => bb
    None => merge_bb
  }

  // Create the switch instruction
  let switch_inst = self.builder.createSwitch(cond_int, default_bb)

  // Get the integer type of the condition
  let cond_ty = cond_int.getType().tryAsIntType().unwrap()
  let bit_width = cond_ty.getBitWidth()

  // Add all cases to the switch instruction
  for case_info in cases {
    // Create constant with the same type as the condition
    let const_val = match bit_width {
      8 => self.llvm_ctx.getConstInt8(case_info.value.to_int())
      16 =>
        self.llvm_ctx.getConstInt16(Int16::from_int(case_info.value.to_int()))
      32 => self.llvm_ctx.getConstInt32(case_info.value.to_int())
      64 => self.llvm_ctx.getConstInt64(case_info.value)
      _ =>
        raise IllegalLLVMUsage(
          "Unsupported integer width \{bit_width} for switch case",
        )
    }
    switch_inst.addCase(const_val, case_info.bb)
  }

  // Save the current break target and set new one for switch
  // (break in switch should jump to merge_bb)
  // Note: continue is not valid in switch, but we use merge_bb for consistency
  self.push_loop_targets(merge_bb, merge_bb)

  // Emit the switch body
  // The body is typically a compound statement containing case/default labels
  self.emit_switch_body(switch_stmt.body, cases, default_bb_opt, merge_bb)

  // Restore break/continue targets
  self.pop_loop_targets()

  // Continue inserting after the switch
  self.builder.setInsertPoint(merge_bb)
}

///|
/// Collect all case and default labels from a switch body
///
/// Returns a tuple of (cases, default_bb_option)
fn Context::collect_switch_cases(
  self : Context,
  body : @parser.Statement,
  func : @IR.Function,
) -> (Array[CaseInfo], @IR.BasicBlock?) raise {
  let cases : Array[CaseInfo] = []
  let default_bb_ref : Ref[@IR.BasicBlock?] = { val: None }

  // The body should be a compound statement
  match body.kind {
    Compound(compound) =>
      for item in compound.items {
        match item {
          Left(stmt) =>
            self.collect_cases_from_stmt(stmt, func, cases, default_bb_ref)
          Right(_) => () // declarations don't contain case labels
        }
      }
    _ =>
      // Single statement (rare but valid)
      self.collect_cases_from_stmt(body, func, cases, default_bb_ref)
  }
  (cases, default_bb_ref.val)
}

///|
/// Recursively collect case/default labels from a statement
fn Context::collect_cases_from_stmt(
  self : Context,
  stmt : @parser.Statement,
  func : @IR.Function,
  cases : Array[CaseInfo],
  default_bb : Ref[@IR.BasicBlock?],
) -> Unit raise {
  match stmt.kind {
    Case(const_expr, inner_stmt) => {
      // Evaluate the constant expression to get the case value
      let case_value = const_expr.eval_as_int().to_int64()
      let bb = func.addBasicBlock()
      cases.push(CaseInfo::{ value: case_value, bb })

      // Recursively check the inner statement (for nested cases like case 1: case 2: ...)
      self.collect_cases_from_stmt(inner_stmt, func, cases, default_bb)
    }
    DefaultCase(inner_stmt) => {
      if default_bb.val is Some(_) {
        raise SemanticError("Multiple default cases in switch statement")
      }
      let bb = func.addBasicBlock()
      default_bb.val = Some(bb)

      // Recursively check the inner statement
      self.collect_cases_from_stmt(inner_stmt, func, cases, default_bb)
    }
    // Need to recurse into compound statements, loops, etc. to find nested cases (Duff's Device)
    Compound(compound) =>
      for item in compound.items {
        match item {
          Left(inner_stmt) =>
            self.collect_cases_from_stmt(inner_stmt, func, cases, default_bb)
          Right(_) => ()
        }
      }
    While(while_stmt) =>
      self.collect_cases_from_stmt(while_stmt.body, func, cases, default_bb)
    DoWhile(do_while_stmt) =>
      self.collect_cases_from_stmt(do_while_stmt.body, func, cases, default_bb)
    For(for_stmt) =>
      self.collect_cases_from_stmt(for_stmt.body, func, cases, default_bb)
    If(if_stmt) => {
      self.collect_cases_from_stmt(if_stmt.then_stmt, func, cases, default_bb)
      match if_stmt.else_stmt {
        Some(else_stmt) =>
          self.collect_cases_from_stmt(else_stmt, func, cases, default_bb)
        None => ()
      }
    }
    Labeled(_, inner_stmt) =>
      self.collect_cases_from_stmt(inner_stmt, func, cases, default_bb)
    _ => ()
  }
}

///|
/// Emit the body of a switch statement
///
/// This handles the sequential emission of statements within the switch,
/// properly connecting case labels to their code.
fn Context::emit_switch_body(
  self : Context,
  body : @parser.Statement,
  cases : Array[CaseInfo],
  default_bb : @IR.BasicBlock?,
  merge_bb : @IR.BasicBlock,
) -> Unit raise {
  guard body.kind is Compound(compound) else {
    // Single statement body (rare)
    self.emit_statement(body)

    // Branch to merge if not terminated
    let current_bb = self.builder.getInsertBlock()
    if current_bb.getTerminator() is None {
      self.builder.createBr(merge_bb) |> ignore
    }
  }

  // If body is a compound statement, proceed
  // Enter new scope for the switch body
  self.enter_scope()

  // Track which case we're currently in
  let case_idx : Ref[Int] = Ref::new(0)
  let in_default : Ref[Bool] = Ref::new(false)
  let items_len = compound.items.length()
  fn emit_stmt_in_switch_body(i : Int, stmt : @parser.Statement) -> Unit raise {
    match stmt.kind {
      Case(_) => {
        // Check if current block needs a fallthrough branch
        let current_bb = self.builder.getInsertBlock()
        if current_bb.getTerminator() is None {
          // Add fallthrough branch to the new case block
          if case_idx.val < cases.length() {
            self.builder.createBr(cases[case_idx.val].bb) |> ignore
          }
        }

        // Set insert point to this case's basic block
        if case_idx.val < cases.length() {
          self.builder.setInsertPoint(cases[case_idx.val].bb)
          case_idx.val = case_idx.val + 1
        }
        // Emit the statement (which will recursively handle nested cases)
        self.emit_case_stmt(stmt, cases, case_idx, default_bb, in_default)
      }
      DefaultCase(_) => {
        // Check if current block needs a fallthrough branch
        let current_bb = self.builder.getInsertBlock()

        // Set insert point to default basic block
        match default_bb {
          Some(bb) => {
            if current_bb.getTerminator() is None {
              // Add fallthrough branch to default block
              self.builder.createBr(bb) |> ignore
            }
            self.builder.setInsertPoint(bb)
            in_default.val = true
          }
          None => raise SemanticError("No default case found")
        }
        // Emit the statement
        self.emit_case_stmt(stmt, cases, case_idx, default_bb, in_default)
      }
      _ => {
        // Regular statement - just emit it
        let is_term = self.emit_statement_maybe_term(stmt)

        // If this is the last statement and not a terminator, branch to merge
        if i == items_len - 1 && !is_term {
          self.builder.createBr(merge_bb) |> ignore
        }
      }
    }
  }

  // Emit each statement in the compound
  for i = 0; i < items_len; i = i + 1 {
    let item = compound.items[i]
    match item {
      Left(stmt) => emit_stmt_in_switch_body(i, stmt)
      Right(decl) => self.emit_local_decl(decl)
    }
  }
  self.exit_scope()
}

///|
/// Emit a case or default statement
///
/// Handles the recursive structure of case labels (case can contain case)
fn Context::emit_case_stmt(
  self : Context,
  stmt : @parser.Statement,
  cases : Array[CaseInfo],
  case_idx : Ref[Int],
  default_bb : @IR.BasicBlock?,
  in_default : Ref[Bool],
) -> Unit raise {
  match stmt.kind {
    Case(_, inner_stmt) =>
      // The case label itself doesn't generate code, just a basic block entry
      // Recursively emit the inner statement
      self.emit_case_stmt(inner_stmt, cases, case_idx, default_bb, in_default)
    DefaultCase(inner_stmt) =>
      // Similarly, default label doesn't generate code
      self.emit_case_stmt(inner_stmt, cases, case_idx, default_bb, in_default)
    _ =>
      // This is the actual statement after the case/default label
      // Use the special emit function that handles nested cases
      self.emit_statement_with_cases(
        stmt, cases, case_idx, default_bb, in_default,
      )
  }
}

///|
/// Emit a statement that may contain nested case labels (for Duff's Device)
fn Context::emit_statement_with_cases(
  self : Context,
  stmt : @parser.Statement,
  cases : Array[CaseInfo],
  case_idx : Ref[Int],
  default_bb : @IR.BasicBlock?,
  in_default : Ref[Bool],
) -> Unit raise {
  match stmt.kind {
    Case(_, _) => {
      // Handle nested case label
      let current_bb = self.builder.getInsertBlock()
      if current_bb.getTerminator() is None {
        if case_idx.val < cases.length() {
          self.builder.createBr(cases[case_idx.val].bb) |> ignore
        }
      }
      if case_idx.val < cases.length() {
        self.builder.setInsertPoint(cases[case_idx.val].bb)
        case_idx.val = case_idx.val + 1
      }
      self.emit_case_stmt(stmt, cases, case_idx, default_bb, in_default)
    }
    DefaultCase(_) => {
      let current_bb = self.builder.getInsertBlock()
      match default_bb {
        Some(bb) => {
          if current_bb.getTerminator() is None {
            self.builder.createBr(bb) |> ignore
          }
          self.builder.setInsertPoint(bb)
          in_default.val = true
        }
        None => raise SemanticError("No default case found")
      }
      self.emit_case_stmt(stmt, cases, case_idx, default_bb, in_default)
    }
    DoWhile(do_while_stmt) =>
      // Special handling for do-while with nested cases (Duff's Device)
      self.emit_do_while_with_cases(
        do_while_stmt, cases, case_idx, default_bb, in_default,
      )
    _ =>
      // Regular statement, just emit it normally
      self.emit_statement(stmt)
  }
}

///|
/// Emit a do-while statement that may contain nested case labels
fn Context::emit_do_while_with_cases(
  self : Context,
  do_while_stmt : @parser.DoWhileStmt,
  cases : Array[CaseInfo],
  case_idx : Ref[Int],
  default_bb : @IR.BasicBlock?,
  in_default : Ref[Bool],
) -> Unit raise {
  let func = self.current_func.unwrap()
  let body_bb = func.addBasicBlock()
  let cond_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()

  // Save old break/continue targets and set new ones
  self.push_loop_targets(merge_bb, cond_bb)

  // Jump to body
  self.builder.createBr(body_bb) |> ignore
  self.builder.setInsertPoint(body_bb)

  // Emit body with case handling
  self.emit_statement_body_with_cases(
    do_while_stmt.body,
    cases,
    case_idx,
    default_bb,
    in_default,
  )

  // Check if current block has terminator, if not jump to condition
  let current_bb = self.builder.getInsertBlock()
  if current_bb.getTerminator() is None {
    self.builder.createBr(cond_bb) |> ignore
  }

  // Emit condition
  self.builder.setInsertPoint(cond_bb)
  let cond_raw = self.emit_expr(do_while_stmt.cond)
  let cond_val = self.to_bool(cond_raw)
  self.builder.createCondBr(cond_val, body_bb, merge_bb) |> ignore

  // Restore break/continue targets
  self.pop_loop_targets()

  // Continue at merge
  self.builder.setInsertPoint(merge_bb)
}

///|
/// Emit statement body with case handling
fn Context::emit_statement_body_with_cases(
  self : Context,
  stmt : @parser.Statement,
  cases : Array[CaseInfo],
  case_idx : Ref[Int],
  default_bb : @IR.BasicBlock?,
  in_default : Ref[Bool],
) -> Unit raise {
  match stmt.kind {
    Compound(compound) =>
      for item in compound.items {
        match item {
          Left(inner_stmt) =>
            self.emit_statement_with_cases(
              inner_stmt, cases, case_idx, default_bb, in_default,
            )
          Right(decl) => self.emit_local_decl(decl)
        }
      }
    _ =>
      self.emit_statement_with_cases(
        stmt, cases, case_idx, default_bb, in_default,
      )
  }
}
