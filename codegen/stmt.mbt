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

///|
fn Context::emit_local_variable(
  self : Context,
  ty : @parser.CType,
  name : String,
  init_expr : @parser.Initializer?,
) -> Unit raise {
  let llvm_ty = self.ctype_to_llvm_type(ty)
  let alloca = self.builder.createAlloca(llvm_ty, name~)
  self.var_env.set(name, alloca)
  self.var_types.set(name, ty)
  let init_expr = match init_expr {
    Some(init_expr) => init_expr
    None => return
  }
  match init_expr.kind {
    AssignExpr(assign_expr) => {
      let value = self.emit_assign_expr(assign_expr)
      self.builder.createStore(value, alloca) |> ignore
    }
    InitializerList(_) =>
      raise Unimplemented("Initializer list not implemented yet")
    _ => raise Unimplemented("Initializer kind not implemented yet")
  }
}

///|
pub fn Context::emit_statement(
  self : Context,
  stmt : @parser.Statement,
) -> Unit raise {
  match stmt.kind {
    ReturnVoid => self.builder.createRetVoid() |> ignore
    Return(expr) => {
      let value = self.emit_expr(expr)
      let _ = self.builder.createRet(value)

    }
    Compound(comp) => self.emit_compound_stmt(comp)
    If(if_stmt) => self.emit_if_stmt(if_stmt)
    // Expression statement - evaluate the expression for its side effects
    Expr(expr) => {
      let _ = self.emit_expr(expr)

    }
    Noop => ()
    _ => raise Unimplemented("Statement emission not implemented yet")
  }
}

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
  let else_bb = match if_stmt.else_stmt {
    Some(_) => func.addBasicBlock()
    None => merge_bb
  }
  let _ = self.builder.createCondBr(cond_bool, then_bb, else_bb)

  // then branch
  self.builder.setInsertPoint(then_bb)
  let then_term = self.emit_statement_maybe_term(if_stmt.then_stmt)
  if !then_term {
    let _ = self.builder.createBr(merge_bb)

  }

  // else branch
  match if_stmt.else_stmt {
    Some(else_stmt) => {
      self.builder.setInsertPoint(else_bb)
      let else_term = self.emit_statement_maybe_term(else_stmt)
      if !else_term {
        let _ = self.builder.createBr(merge_bb)

      }
    }
    None => ()
  }
  self.builder.setInsertPoint(merge_bb)
}

///|
fn Context::emit_statement_maybe_term(
  self : Context,
  stmt : @parser.Statement,
) -> Bool raise {
  match stmt.kind {
    Return(_) | ReturnVoid => {
      self.emit_statement(stmt)
      true
    }
    _ => {
      self.emit_statement(stmt)
      false
    }
  }
}

///|
fn Context::to_bool(self : Context, val : &@IR.Value) -> &@IR.Value raise {
  let ty = val.getType()
  match ty.tryAsIntType() {
    Some(int_ty) => {
      let zero = self.llvm_ctx.getConstZero(int_ty)
      self.builder.createICmpNE(val, zero)
    }
    None =>
      match ty.tryAsFPType() {
        Some(fp_ty) => {
          let zero = self.llvm_ctx.getConstZero(fp_ty)
          self.builder.createFCmpONE(val, zero)
        }
        None =>
          codegen_unreachable(msg="Unsupported condition type for if statement")
      }
  }
}
