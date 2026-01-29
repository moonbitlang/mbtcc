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
      Case(_, _) | CaseRange(_, _, _) => {
        let (labels, _payload) = unwind_case_chain(stmt)
        for rng in labels {
          let (start, end) = rng
          for v = start; v <= end; v = v + 1 {
            guard top.case_map.get(v) is None else {
              raise SemanticError("Duplicate `case` label: \{v}")
            }
            let bb = func.addBasicBlock()
            top.case_map.set(v, bb)
            let ci32 = self.llvm_ctx.getConstInt32(v)
            let _ = top.switch_inst.addCase(ci32, bb)

          }
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
      Left({ kind: Case(_, _), .. } | { kind: CaseRange(_, _, _), .. } as stmt) => {
        let (labels, payload) = unwind_case_chain(stmt)
        guard labels.length() > 0 else {
          raise SemanticError("Internal error: empty case chain")
        }

        // 依次切换到每个 case label 的基本块；链式 case 会形成空块串联
        for rng in labels {
          let (start, end) = rng
          for v = start; v <= end; v = v + 1 {
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
        }

        // 在最后一个 label 块里发射真正的语句
        if current_bb is Some(bb) {
          if bb.getTerminator() is None {
            // payload 不应再是 case/default，否则说明 unwind 不完整
            match payload.kind {
              Case(_, _) | CaseRange(_, _, _) | DefaultCase(_) =>
                raise SemanticError("Invalid nested label in switch body")
              _ => {
                self.emit_statement(payload)
                // payload 可能会创建新基本块并移动 insert point（如 Duff's device 的 do-while）
                current_bb = Some(self.builder.getInsertBlock())
              }
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
            Case(_, _) | CaseRange(_, _, _) | DefaultCase(_) =>
              raise SemanticError("Invalid nested label in switch body")
            _ => {
              self.emit_statement(payload)
              current_bb = Some(self.builder.getInsertBlock())
            }
          }
        }
      }
      Left(stmt) =>
        // 普通语句：只在某个 case/default 已经“激活”后才发射
        match current_bb {
          Some(bb) =>
            if bb.getTerminator() is None {
              self.emit_statement(stmt)
              current_bb = Some(self.builder.getInsertBlock())
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
              current_bb = Some(self.builder.getInsertBlock())
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
fn Context::emit_case_range_label_in_switch(
  self : Context,
  start_expr : @parser.ConstantExpr,
  end_expr : @parser.ConstantExpr,
  inner : @parser.Statement,
) -> Unit raise {
  guard self.switch_ctx_stack.length() > 0 else {
    raise SemanticError("`case` used outside of switch")
  }
  let ctx = self.switch_ctx_stack.pop().unwrap()
  let v1 = case_value_as_int(start_expr)
  let v2 = case_value_as_int(end_expr)
  let func = self.current_func.unwrap()

  // Determine target block
  let target_bb = match ctx.case_map.get(v1) {
    Some(bb) => bb
    None => func.addBasicBlock()
  }
  for v = v1; v <= v2; v = v + 1 {
    match ctx.case_map.get(v) {
      Some(bb) =>
        if bb != target_bb {
          raise SemanticError("Duplicate or overlapping case label: \{v}")
        }
      None => {
        // Ensure consistent state: if v1 was present, all must be present
        // If v1 was absent, all must be absent
        // Exception: nested case range that overlaps with existing top-level case?
        // That is duplicate.
        // If v1 was absent (None), then target_bb is new.
        // If v is present (Some), it maps to old BB. New BB != Old BB.
        // So checking `bb != target_bb` handles this.
        // But here we are in None branch.

        ctx.case_map.set(v, target_bb)
        let ci32 = self.llvm_ctx.getConstInt32(v)
        let _ = ctx.switch_inst.addCase(ci32, target_bb)

      }
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
    Bool => true
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
) -> (Array[(Int, Int)], @parser.Statement) raise {
  let labels : Array[(Int, Int)] = Array::new()
  fn go(
    cur : @parser.Statement,
    labels : Array[(Int, Int)],
  ) -> @parser.Statement raise {
    match cur.kind {
      Case(const_expr, inner) => {
        let v = case_value_as_int(const_expr)
        labels.push((v, v))
        go(inner, labels)
      }
      CaseRange(start, end, inner) => {
        let v1 = case_value_as_int(start)
        let v2 = case_value_as_int(end)
        if v1 <= v2 {
          labels.push((v1, v2))
        }
        go(inner, labels)
      }
      _ => cur
    }
  }

  let payload = go(stmt, labels)
  (labels, payload)
}
