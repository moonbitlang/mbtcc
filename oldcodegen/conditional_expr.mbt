///|
fn Context::emit_conditional_expr(
  self : Context,
  cond_expr : @parser.ConditionalExpr,
) -> &@IR.Value raise {
  match cond_expr.kind {
    LogicalOrExpr(expr) => self.emit_logical_or_expr(expr)
    ConditionalExpr(cond, then_expr, else_expr) =>
      self.emit_select_expr(cond, then_expr, else_expr)
    GnuCondOmitThen(cond, else_expr) =>
      self.emit_select_expr_omit(cond_expr.ctype, cond, else_expr)
  }
}

///|
fn Context::emit_select_expr_omit(
  self : Context,
  result_ctype : @parser.CType,
  cond : @parser.LogicalOrExpr,
  else_expr : @parser.ConditionalExpr,
) -> &@IR.Value raise {
  let func = self.current_func.unwrap()
  let then_bb = func.addBasicBlock()
  let else_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()

  // Evaluate `cond` once.
  let cond_raw = self.emit_logical_or_expr(cond)
  let cond_bool = self.to_bool(cond_raw)
  self.builder.createCondBr(cond_bool, then_bb, else_bb) |> ignore
  let result_is_void = result_ctype.dataKind is Void

  // then branch: value is `cond_raw` itself.
  self.builder.setInsertPoint(then_bb)
  let then_val = if result_is_void {
    cond_raw
  } else {
    self.cast_value_to_ctype(cond_raw, cond.ctype, result_ctype)
  }
  let then_end = self.builder.getInsertBlock()
  self.builder.createBr(merge_bb) |> ignore

  // else branch
  self.builder.setInsertPoint(else_bb)
  let else_raw = self.emit_conditional_expr(else_expr)
  let else_val = if result_is_void {
    else_raw
  } else {
    self.cast_value_to_ctype(else_raw, else_expr.ctype, result_ctype)
  }
  let else_end = self.builder.getInsertBlock()
  self.builder.createBr(merge_bb) |> ignore

  // merge
  self.builder.setInsertPoint(merge_bb)
  if result_is_void {
    self.llvm_ctx.getConstInt32(0).asValueEnum().asValueClass()
  } else {
    let ty = self.ctype_to_llvm_type(result_ctype)
    let phi = self.builder.createPHI(ty)
    phi.addIncoming(then_val, then_end) |> ignore
    phi.addIncoming(else_val, else_end) |> ignore
    phi.asValueEnum().asValueClass()
  }
}

///|
fn Context::emit_select_expr(
  self : Context,
  cond : @parser.LogicalOrExpr,
  then_expr : @parser.Expr,
  else_expr : @parser.ConditionalExpr,
) -> &@IR.Value raise {
  let func = self.current_func.unwrap()
  let then_bb = func.addBasicBlock()
  let else_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()
  let cond_raw = self.emit_logical_or_expr(cond)
  let cond_bool = self.to_bool(cond_raw)
  self.builder.createCondBr(cond_bool, then_bb, else_bb) |> ignore

  // Determine result type (per parser rules).
  let result_is_void = then_expr.ctype.dataKind is Void ||
    else_expr.ctype.dataKind is Void
  let result_ty = if result_is_void {
    None
  } else if then_expr.ctype == else_expr.ctype {
    Some(then_expr.ctype)
  } else {
    @parser.CType::common_type(then_expr.ctype, else_expr.ctype)
  }

  // then branch
  self.builder.setInsertPoint(then_bb)
  let then_raw = self.emit_expr(then_expr)
  let then_val = match result_ty {
    Some(t) => self.cast_value_to_ctype(then_raw, then_expr.ctype, t)
    None => then_raw
  }
  let then_end = self.builder.getInsertBlock()
  self.builder.createBr(merge_bb) |> ignore

  // else branch
  self.builder.setInsertPoint(else_bb)
  let else_raw = self.emit_conditional_expr(else_expr)
  let else_val = match result_ty {
    Some(t) => self.cast_value_to_ctype(else_raw, else_expr.ctype, t)
    None => else_raw
  }
  let else_end = self.builder.getInsertBlock()
  self.builder.createBr(merge_bb) |> ignore

  // merge
  self.builder.setInsertPoint(merge_bb)
  if result_is_void {
    // For void-typed conditional expressions, only side effects matter.
    // Return a dummy value so callers that expect a value can proceed.
    self.llvm_ctx.getConstInt32(0).asValueEnum().asValueClass()
  } else {
    let ty = self.ctype_to_llvm_type(result_ty.unwrap())
    let phi = self.builder.createPHI(ty)
    phi.addIncoming(then_val, then_end) |> ignore
    phi.addIncoming(else_val, else_end) |> ignore
    phi.asValueEnum().asValueClass()
  }
}
