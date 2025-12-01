///|
pub fn Context::emit_local_decl(
  self : Context,
  decl : @parser.Declaration,
) -> Unit raise {
  // emit local variable declaration
  ignore(self)
  ignore(decl)
  raise Unimplemented("Local variable declaration emission not implemented yet")
}

///|
pub fn Context::emit_statement(
  self : Context,
  stmt : @parser.Statement,
) -> Unit raise {
  match stmt.kind {
    ReturnVoid => {
      self.builder.createRetVoid() |> ignore
    }
    _ => raise Unimplemented("Statement emission not implemented yet")
  }
}
