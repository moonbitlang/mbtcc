///|
pub fn Context::emit_local_decl(
  self : Context,
  decl : @parser.Declaration,
) -> Unit raise {
  match decl.kind {
    VariableDeclaration(ty, name, init_expr, is_static~, ..) =>
      if is_static {
        self.emit_static_local_variable(ty, name, init_expr) |> ignore
      } else {
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
  let alloca = self.builder.createAlloca(llvm_ty)
  self.var_env.set(name, alloca)
  self.var_types.set(name, ty)
  let init_expr = match init_expr {
    Some(init_expr) => init_expr
    None => return
  }
  match init_expr.kind {
    AssignExpr(assign_expr) => {
      let value = self.emit_assign_expr(assign_expr)
      let value = self.cast_value_to_ctype(value, assign_expr.ctype, ty)
      self.builder.createStore(value, alloca) |> ignore
    }
    InitializerList(initializers) =>
      self.emit_initializer_list_to_ptr(alloca, ty, initializers)
    _ => raise Unimplemented("Initializer kind not implemented yet")
  }
}

///|
fn Context::emit_static_local_variable(
  self : Context,
  ty : @parser.CType,
  name : String,
  init_expr : @parser.Initializer?,
) -> Unit raise {
  guard self.current_func is Some(func) else {
    raise SemanticError("Static local used outside of a function")
  }
  let func_name = func.getNameOrSlotStr()
  let global_name = "\{func_name}__\{name}__static"
  let llvm_ty = self.ctype_to_llvm_type(ty)
  let init_const = match init_expr {
    Some(init_expr) => self.emit_initializer(init_expr, ty)
    None => self.llvm_ctx.getConstZero(llvm_ty)
  }
  let gvar = self.llvm_mod.addGlobalVariable(
    llvm_ty,
    global_name,
    initializer=init_const,
    linkage?=Some(Internal),
  )
  let gvar_val = gvar.asValueEnum().asValueClass()
  self.var_env.set(name, gvar_val)
  self.var_types.set(name, ty)
}

///|
fn Context::push_loop_targets(
  self : Context,
  break_bb : @IR.BasicBlock,
  continue_bb : @IR.BasicBlock,
) -> Unit {
  self.break_stack.push(break_bb)
  self.continue_stack.push(continue_bb)
}

///|
fn Context::pop_loop_targets(self : Context) -> Unit {
  let _ = self.break_stack.pop()
  let _ = self.continue_stack.pop()

}

///|
fn Context::push_switch_break_target(
  self : Context,
  break_bb : @IR.BasicBlock,
) -> Unit {
  self.break_stack.push(break_bb)
}

///|
fn Context::pop_switch_break_target(self : Context) -> Unit {
  let _ = self.break_stack.pop()

}

///|
fn Context::current_break_target(self : Context) -> @IR.BasicBlock raise {
  guard self.break_stack.length() > 0 else {
    raise SemanticError("`break` used outside of loop or switch")
  }
  self.break_stack[self.break_stack.length() - 1]
}

///|
fn Context::current_continue_target(self : Context) -> @IR.BasicBlock raise {
  guard self.continue_stack.length() > 0 else {
    raise SemanticError("`continue` used outside of loop")
  }
  self.continue_stack[self.continue_stack.length() - 1]
}

///|
fn Context::get_label(self : Context, name : String) -> @IR.BasicBlock {
  match self.labels.get(name) {
    Some(bb) => bb
    None => {
      let func = self.current_func.unwrap()
      let bb = func.addBasicBlock(name~)
      self.labels.set(name, bb)
      bb
    }
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
      guard self.current_ret_ty is Some(ret_ty) else {
        raise SemanticError("Return used outside of a function")
      }
      let casted = self.cast_value_to_ctype(value, expr.ctype, ret_ty)
      let _ = self.builder.createRet(casted)

    }
    Compound(comp) => self.emit_compound_stmt(comp)
    If(if_stmt) => self.emit_if_stmt(if_stmt)
    For(for_stmt) => self.emit_for_stmt(for_stmt)
    While(while_stmt) => self.emit_while_stmt(while_stmt)
    DoWhile(do_while_stmt) => self.emit_do_while_stmt(do_while_stmt)
    Break => self.emit_break()
    Continue => self.emit_continue()
    // Expression statement - evaluate the expression for its side effects
    Expr(expr) => {
      let _ = self.emit_expr(expr)

    }
    Noop => ()
    Switch(switch_stmt) => self.emit_switch_stmt(switch_stmt)
    DefaultCase(inner) => self.emit_default_label_in_switch(inner)
    Case(const_expr, inner) => self.emit_case_label_in_switch(const_expr, inner)
    CaseRange(start, end, inner) =>
      self.emit_case_range_label_in_switch(start, end, inner)
    Labeled(label, stmt) => {
      let bb = self.get_label(label)
      if self.builder.getInsertBlock().getTerminator() is None {
        self.builder.createBr(bb) |> ignore
      }
      self.builder.setInsertPoint(bb)
      self.emit_statement(stmt)
    }
    Goto(label) => {
      let bb = self.get_label(label)
      self.builder.createBr(bb) |> ignore
      let func = self.current_func.unwrap()
      let next_bb = func.addBasicBlock(name="after_goto")
      self.builder.setInsertPoint(next_bb)
    }
  }
}

///|
fn Context::emit_statement_maybe_term(
  self : Context,
  stmt : @parser.Statement,
) -> Bool raise {
  match stmt.kind {
    Return(_) | ReturnVoid | Break | Continue | Goto(_) => {
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

///|
fn Context::emit_for_stmt(
  self : Context,
  for_stmt : @parser.ForStmt,
) -> Unit raise {
  // for 循环拥有自己的作用域，保持与解析阶段一致
  let _ = self.enter_scope()

  // 初始化子句
  match for_stmt.init {
    Some(Expr(expr)) => {
      let _ = self.emit_expr(expr)

    }
    Some(Declaration(decls)) =>
      for decl in decls {
        self.emit_local_decl(decl)
      }
    None => ()
  }

  // 基本块布局：cond -> body -> update -> cond，cond false 跳转 merge
  let func = self.current_func.unwrap()
  let cond_bb = func.addBasicBlock()
  let body_bb = func.addBasicBlock()
  let update_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()
  self.push_loop_targets(merge_bb, update_bb)

  // 跳转到条件块
  let _ = self.builder.createBr(cond_bb)

  // 条件判定
  self.builder.setInsertPoint(cond_bb)
  match for_stmt.cond {
    Some(cond_expr) => {
      let cond_raw = self.emit_expr(cond_expr)
      let cond_val = self.to_bool(cond_raw)
      let _ = self.builder.createCondBr(cond_val, body_bb, merge_bb)

    }
    None => {
      // 无条件：直接进入循环体
      let _ = self.builder.createBr(body_bb)

    }
  }

  // 循环体
  self.builder.setInsertPoint(body_bb)
  let body_term = self.emit_statement_maybe_term(for_stmt.body)
  if !body_term {
    let _ = self.builder.createBr(update_bb)

  }

  // 更新子句
  self.builder.setInsertPoint(update_bb)
  match for_stmt.update {
    Some(update_expr) => {
      let _ = self.emit_expr(update_expr)

    }
    None => ()
  }
  let _ = self.builder.createBr(cond_bb)

  // 退出循环作用域，并继续在 merge 后插入
  self.builder.setInsertPoint(merge_bb)
  let _ = self.exit_scope()
  self.pop_loop_targets()
}

///|
fn Context::emit_break(self : Context) -> Unit raise {
  let target = self.current_break_target()
  self.builder.createBr(target) |> ignore
}

///|
fn Context::emit_continue(self : Context) -> Unit raise {
  let target = self.current_continue_target()
  self.builder.createBr(target) |> ignore
}
