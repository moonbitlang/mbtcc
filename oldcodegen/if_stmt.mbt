///|
fn Context::emit_if_stmt(
  self : Context,
  if_stmt : @parser.IfStmt,
) -> Unit raise {
  let cond_raw = self.emit_expr(if_stmt.cond)
  let cond_bool = self.to_bool(cond_raw)
  let func = self.current_func.unwrap()
  let then_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()
  let else_bb = func.addBasicBlock()
  let _ = self.builder.createCondBr(cond_bool, then_bb, else_bb)

  // then branch
  self.builder.setInsertPoint(then_bb)
  let then_term = self.emit_statement_maybe_term(if_stmt.then_stmt)
  if !then_term {
    self.builder.createBr(merge_bb) |> ignore
  }

  // else branch
  self.builder.setInsertPoint(else_bb)
  let else_term = match if_stmt.else_stmt {
    Some(else_stmt) => self.emit_statement_maybe_term(else_stmt)
    None => false
  }
  if !else_term {
    self.builder.createBr(merge_bb) |> ignore
  }
  self.builder.setInsertPoint(merge_bb)
  if then_term && else_term {
    // both branches terminated, remove the merge block
    merge_bb.removeFromParent()
  }
}
