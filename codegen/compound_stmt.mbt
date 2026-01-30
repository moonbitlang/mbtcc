///|
pub fn Context::emit_compound_stmt(
  self : Context,
  comp_stmt : @parser.CompoundStmt,
) -> Unit raise {
  let _ = self.enter_scope()
  let { items, .. } = comp_stmt
  for i, item in items {
    match item {
      Left(stmt) => self.emit_statement(stmt)
      Right(decl) => self.emit_local_decl(decl)
    }
    if i + 1 < items.length() {
      match self.builder.getInsertBlock() {
        Some(bb) =>
          if bb.getTerminator() is Some(_) {
            let func = self.current_func.unwrap()
            let cont_bb = func.addBasicBlock(name="after_term")
            self.builder.setInsertPoint(cont_bb)
          }
        None => ()
      }
    }
  }
  let _ = self.exit_scope()

}
