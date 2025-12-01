///|
pub fn Context::emit_local_decl(
  self : Context,
  decl : @parser.Declaration,
) -> Unit raise {
  match decl.kind {
    VariableDeclaration(ty, name, init_expr, is_static~, ..) => {
      ignore(is_static)
      self.emit_local_variable(ty, name, init_expr) |> ignore
    }
    TypeDeclaration(ty) => {
      ignore(ty)
      raise Unimplemented("Local Type declaration not implemented yet")
    }
    // local `typedef` is a no-op in LLVM
    // we already handled it in the parser phase
    TypeDef(_) => ()
  }
}

fn Context::emit_local_variable(
  self : Context,
  ty : @parser.CType,
  name : String,
  init_expr : @parser.Initializer?,
) -> Unit raise {
  let llvm_ty = self.ctype_to_llvm_type(ty)
  let alloca = self.builder.createAlloca(llvm_ty, name~)
  self.var_env.set(name, alloca)
  let init_expr = match init_expr {
    Some(init_expr) => init_expr
    None => return 
  }
  match init_expr.kind {
    AssignExpr(assign_expr) => {
      let value = self.emit_assign_expr(assign_expr)
      self.builder.createStore(value, alloca) |> ignore
    }
    InitializerList(_) => {
      raise Unimplemented("Initializer list not implemented yet")
    }
    _ => {
      raise Unimplemented("Initializer kind not implemented yet")
    }
  }
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
    Return(expr) => {
      let value = self.emit_expr(expr)
      self.builder.createRet(value) |> ignore
    }
    _ => raise Unimplemented("Statement emission not implemented yet")
  }
}
