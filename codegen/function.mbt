///|
pub fn Context::emit_function_def(
  self : Context,
  func_def : @parser.FunctionDefinition,
) -> Unit raise {
  let { name, params, ret_ty, is_static, is_variadic, body } = func_def
  // if `static` set, we just ignore it for now
  ignore(is_static)
  // LLVM supports variadic functions; pass is_variadic to function type.
  // Record function signature so calls can cast args to param types (even for static functions).
  let func_sig = @parser.CType::default_with(
    Function(params, ret_ty, is_variadic=is_variadic),
  )
  self.func_decls.set(name, func_sig)
  let param_types : Array[&@IR.Type] = Array::new()
  let param_names : Array[String] = Array::new()
  for param in params {
    let (param_ty, param_name) = param
    let llvm_param_ty = self.ctype_to_llvm_type(param_ty)
    param_types.push(llvm_param_ty)
    param_names.push(param_name)
  }
  let llvm_ret_ty = self.ctype_to_llvm_type(ret_ty)
  let func_type = self.llvm_ctx.getFunctionType(
    llvm_ret_ty,
    param_types,
    isVarArg=is_variadic,
  )
  let linkage : @IR.Linkage? = if is_static {
    Some(InternalLinkage)
  } else {
    None
  }
  let llvm_func = match self.llvm_mod.getFunction(name) {
    Some(func) => func
    None => self.llvm_mod.addFunction(func_type, name, linkage?=linkage)
  }
  self.current_func = Some(llvm_func)
  self.current_ret_ty = Some(ret_ty)
  self.labels = Map::new()
  // Create entry basic block
  let entry_bb = llvm_func.addBasicBlock(name="entry")
  self.builder.setInsertPoint(entry_bb)
  // Enter new scope for function parameters
  self.enter_scope()
  for i in 0..<param_names.length() {
    let parem_name = param_names[i]
    let (param_ty, _) = params[i]
    let llvm_param = llvm_func.getArg(i).unwrap()
    llvm_param.setName(parem_name)
    let alloca = self.builder.createAlloca(param_types[i])
    let _ = self.builder.createStore(llvm_param, alloca)
    self.var_env.set(parem_name, alloca)
    self.var_types.set(parem_name, param_ty)
  }
  // Run global initializers before main body
  if name == "main" {
    let init_func = self.ensure_global_init_func()
    let args : Array[&@IR.Value] = Array::new()
    let _ = self.builder.createCall(init_func, args)
  }
  self.emit_compound_stmt(body)
  match self.builder.getInsertBlock() {
    Some(cur_bb) => {
      if cur_bb.getTerminator() is None {
        match ret_ty.dataKind {
          Void => self.builder.createRetVoid() |> ignore
          _ => {
            let zero = self.const_zero_value(self.ctype_to_llvm_type(ret_ty))
            self.builder.createRet(zero) |> ignore
          }
        }
      }
    }
    None => ()
  }
  self.exit_scope()
  self.current_func = None
  self.current_ret_ty = None
}
