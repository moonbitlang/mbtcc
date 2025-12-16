///|
fn Context::emit_while_stmt(
  self : Context,
  while_stmt : @parser.WhileStmt,
) -> Unit raise {
  let func = self.current_func.unwrap()
  let cond_bb = func.addBasicBlock()
  let body_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()
  self.push_loop_targets(merge_bb, cond_bb)

  // 初始跳转到条件判断
  let _ = self.builder.createBr(cond_bb)

  // 条件分支
  self.builder.setInsertPoint(cond_bb)
  let cond_raw = self.emit_expr(while_stmt.cond)
  let cond_val = self.to_bool(cond_raw)
  let _ = self.builder.createCondBr(cond_val, body_bb, merge_bb)

  // 循环体
  self.builder.setInsertPoint(body_bb)
  let body_term = self.emit_statement_maybe_term(while_stmt.body)
  if !body_term {
    let _ = self.builder.createBr(cond_bb)

  }

  // 收尾
  self.builder.setInsertPoint(merge_bb)
  self.pop_loop_targets()
}


