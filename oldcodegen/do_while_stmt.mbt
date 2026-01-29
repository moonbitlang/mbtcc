///|
fn Context::emit_do_while_stmt(
  self : Context,
  do_while_stmt : @parser.DoWhileStmt,
) -> Unit raise {
  let func = self.current_func.unwrap()
  let body_bb = func.addBasicBlock()
  let cond_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()
  self.push_loop_targets(merge_bb, cond_bb)

  // 至少执行一次循环体
  let _ = self.builder.createBr(body_bb)
  self.builder.setInsertPoint(body_bb)
  let body_term = self.emit_statement_maybe_term(do_while_stmt.body)
  if !body_term {
    let _ = self.builder.createBr(cond_bb)

  }

  // 条件检查
  self.builder.setInsertPoint(cond_bb)
  let cond_raw = self.emit_expr(do_while_stmt.cond)
  let cond_val = self.to_bool(cond_raw)
  let _ = self.builder.createCondBr(cond_val, body_bb, merge_bb)
  self.builder.setInsertPoint(merge_bb)
  self.pop_loop_targets()
}
