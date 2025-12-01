///|
pub fn Context::emit_local_decl(
  self : Context,
  decl : @parser.Declaration,
) -> Unit raise CodeGenError {
  // emit local variable declaration
  ignore(self)
  ignore(decl)
  raise Unimplemented("Local variable declaration emission not implemented yet")
}

///|
pub fn Context::emit_statement(
  self : Context,
  stmt : @parser.Statement,
) -> Unit raise CodeGenError {
  match stmt.kind {
    ReturnVoid => {
      let _ = self.builder.createRetVoid() catch {
        err =>
          raise IllegalLLVMUsage("Failed to emit return void statement: \{err}")
      }

    }
    _ => raise Unimplemented("Statement emission not implemented yet")
  }
}
