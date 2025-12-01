///|
pub fn Context::emit_compound_stmt(
  self : Context,
  comp_stmt : @parser.CompoundStmt,
) -> Unit raise {
  let _ = self.enter_scope()
  let { items, .. } = comp_stmt
  for item in items {
    match item {
      Left(stmt) => self.emit_statement(stmt)
      Right(decl) => self.emit_local_decl(decl)
    }
  }
  let _ = self.exit_scope()

}
