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
      self.builder.createStore(value, alloca) |> ignore
    }
    InitializerList(_) =>
      raise Unimplemented("Initializer list not implemented yet")
    _ => raise Unimplemented("Initializer kind not implemented yet")
  }
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
    Labeled(_) => raise Unimplemented("Label emission not implemented yet")
    Goto(_) => raise Unimplemented("Goto emission not implemented yet")
  }
}

///|
fn Context::emit_case_label_in_switch(
  self : Context,
  const_expr : @parser.ConstantExpr,
  inner : @parser.Statement,
) -> Unit raise {
  guard self.switch_ctx_stack.length() > 0 else {
    raise SemanticError("`case` used outside of switch")
  }
  let ctx = self.switch_ctx_stack.pop().unwrap()
  let v = case_value_as_int(const_expr)
  let func = self.current_func.unwrap()
  let target_bb = match ctx.case_map.get(v) {
    Some(bb) => bb
    None => {
      let bb = func.addBasicBlock()
      ctx.case_map.set(v, bb)
      let ci32 = self.llvm_ctx.getConstInt32(v)
      let _ = ctx.switch_inst.addCase(ci32, bb)
      bb
    }
  }
  if ctx.active {
    let from_bb = self.builder.getInsertBlock()
    if from_bb.getTerminator() is None {
      let _ = self.builder.createBr(target_bb)

    }
  }
  self.builder.setInsertPoint(target_bb)
  ctx.active = true
  self.switch_ctx_stack.push(ctx)
  self.emit_statement(inner)
}

///|
fn Context::emit_default_label_in_switch(
  self : Context,
  inner : @parser.Statement,
) -> Unit raise {
  guard self.switch_ctx_stack.length() > 0 else {
    raise SemanticError("`default` used outside of switch")
  }
  let ctx = self.switch_ctx_stack.pop().unwrap()
  let target_bb = ctx.default_bb
  ctx.has_default = true
  if ctx.active {
    let from_bb = self.builder.getInsertBlock()
    if from_bb.getTerminator() is None {
      let _ = self.builder.createBr(target_bb)

    }
  }
  self.builder.setInsertPoint(target_bb)
  ctx.active = true
  self.switch_ctx_stack.push(ctx)
  self.emit_statement(inner)
}

///|
fn is_switchable_kind(kind : @parser.CTypeDataKind) -> Bool {
  match kind {
    Char | UChar => true
    Int16 | UInt16 => true
    Int | UInt => true
    Long | ULong | LongLong | ULongLong => true
    Enum(_) => true
    _ => false
  }
}

///|
fn case_value_as_int(c : @parser.ConstantExpr) -> Int raise {
  c.eval_as_int() catch {
    _ => raise SemanticError("Case label must be an integer constant")
  }
}

///|
fn unwind_case_chain(
  stmt : @parser.Statement,
) -> (Array[@parser.ConstantExpr], @parser.Statement) {
  let labels : Array[@parser.ConstantExpr] = Array::new()
  fn go(
    cur : @parser.Statement,
    labels : Array[@parser.ConstantExpr],
  ) -> @parser.Statement {
    match cur.kind {
      Case(const_expr, inner) => {
        labels.push(const_expr)
        go(inner, labels)
      }
      _ => cur
    }
  }

  let payload = go(stmt, labels)
  (labels, payload)
}

///|
fn Context::emit_switch_stmt(
  self : Context,
  switch_stmt : @parser.SwitchStmt,
) -> Unit raise {
  let func = self.current_func.unwrap()

  // switch 的默认/退出块
  let default_bb = func.addBasicBlock()
  let exit_bb = func.addBasicBlock()

  // `break` 在 switch 内跳转到 exit_bb
  self.push_switch_break_target(exit_bb)

  // 计算 switch 条件，并统一转成 i32 以简化常量 case 的匹配
  let cond_raw = self.emit_expr(switch_stmt.expr)
  guard is_switchable_kind(switch_stmt.expr.ctype.dataKind) else {
    raise SemanticError("Switch condition must be an integral type")
  }
  let cond_i32 = self.cast_value_to_ctype(
    cond_raw,
    switch_stmt.expr.ctype,
    @parser.CType::int(),
  )

  // 生成 LLVM switch 指令（这是一个 terminator）
  let switch_inst = self.builder.createSwitch(cond_i32, default_bb)

  // 仅支持 compound body（与 parser 的常见输出一致）
  let body_comp = match switch_stmt.body.kind {
    Compound(comp) => comp
    _ =>
      raise SemanticError("Switch statement body must be a compound statement")
  }

  // 建立 switch codegen 上下文，允许在嵌套语句中继续遇到 case/default 标签（如 Duff's device）
  let case_map : Map[Int, @IR.BasicBlock] = Map::new()
  self.switch_ctx_stack.push(SwitchCodegenCtx::{
    switch_inst,
    case_map,
    default_bb,
    exit_bb,
    active: false,
    has_default: false,
  })

  // 第一遍：预先收集顶层 case（更利于生成稳定的 IR）；嵌套 case 会在遇到时懒创建
  let top = self.switch_ctx_stack.pop().unwrap()
  for stmt in @either.collect_lefts(body_comp.items) {
    match stmt.kind {
      Case(_, _) => {
        let (labels, _payload) = unwind_case_chain(stmt)
        for c in labels {
          let v = case_value_as_int(c)
          guard top.case_map.get(v) is None else {
            raise SemanticError("Duplicate `case` label: \{v}")
          }
          let bb = func.addBasicBlock()
          top.case_map.set(v, bb)
          let ci32 = self.llvm_ctx.getConstInt32(v)
          let _ = top.switch_inst.addCase(ci32, bb)

        }
      }
      DefaultCase(_) => top.has_default = true
      _ => ()
    }
  }
  self.switch_ctx_stack.push(top)

  // 第二遍：按源代码顺序发射 case/default 块内容，并通过 fallthrough 连接
  let mut current_bb : @IR.BasicBlock? = None
  fn maybe_fallthrough_to(
    self : Context,
    from_bb : @IR.BasicBlock,
    to_bb : @IR.BasicBlock,
  ) -> Unit raise {
    if from_bb.getTerminator() is None {
      let _ = self.builder.createBr(to_bb)

    }
  }

  for item in body_comp.items {
    match item {
      Left({ kind: Case(_, _), .. } as stmt) => {
        let (labels, payload) = unwind_case_chain(stmt)
        guard labels.length() > 0 else {
          raise SemanticError("Internal error: empty case chain")
        }

        // 依次切换到每个 case label 的基本块；链式 case 会形成空块串联
        for c in labels {
          let v = case_value_as_int(c)
          let bb = self.switch_ctx_stack[self.switch_ctx_stack.length() - 1].case_map
            .get(v)
            .unwrap()
          if current_bb is Some(prev) {
            maybe_fallthrough_to(self, prev, bb)
          }
          self.builder.setInsertPoint(bb)
          current_bb = Some(bb)
          let top = self.switch_ctx_stack.pop().unwrap()
          top.active = true
          self.switch_ctx_stack.push(top)
        }

        // 在最后一个 label 块里发射真正的语句
        if current_bb is Some(bb) {
          if bb.getTerminator() is None {
            // payload 不应再是 case/default，否则说明 unwind 不完整
            match payload.kind {
              Case(_, _) | DefaultCase(_) =>
                raise SemanticError("Invalid nested label in switch body")
              _ => self.emit_statement(payload)
            }
          }
        }
      }
      Left({ kind: DefaultCase(payload), .. }) => {
        if current_bb is Some(prev) {
          maybe_fallthrough_to(self, prev, default_bb)
        }
        self.builder.setInsertPoint(default_bb)
        current_bb = Some(default_bb)
        let top = self.switch_ctx_stack.pop().unwrap()
        top.active = true
        self.switch_ctx_stack.push(top)
        if default_bb.getTerminator() is None {
          match payload.kind {
            Case(_, _) | DefaultCase(_) =>
              raise SemanticError("Invalid nested label in switch body")
            _ => self.emit_statement(payload)
          }
        }
      }
      Left(stmt) =>
        // 普通语句：只在某个 case/default 已经“激活”后才发射
        match current_bb {
          Some(bb) =>
            if bb.getTerminator() is None {
              self.emit_statement(stmt)
            } else {
              // unreachable，跳过以避免在已终结的块里继续插入指令
              ()
            }
          None => ()
        }
      Right(decl) =>
        match current_bb {
          Some(bb) =>
            if bb.getTerminator() is None {
              self.emit_local_decl(decl)
            } else {
              ()
            }
          None => ()
        }
    }
  }

  // 末尾 fallthrough：最后一个活跃块若未终结则跳出 switch
  match current_bb {
    Some(bb) =>
      if bb.getTerminator() is None {
        self.builder.setInsertPoint(bb)
        let _ = self.builder.createBr(exit_bb)

      }
    None => ()
  }

  // 没有 default 时，default_bb 直接跳到 exit_bb（仍然是 switch 的默认目标）
  if !self.switch_ctx_stack[self.switch_ctx_stack.length() - 1].has_default {
    self.builder.setInsertPoint(default_bb)
    let _ = self.builder.createBr(exit_bb)

  }

  // 退出 switch codegen 上下文
  let _ = self.switch_ctx_stack.pop()
  self.pop_switch_break_target()
  self.builder.setInsertPoint(exit_bb)
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
    Return(_) | ReturnVoid | Break | Continue => {
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
