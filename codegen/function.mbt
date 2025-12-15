///|
pub fn Context::emit_function_def(
  self : Context,
  func_def : @parser.FunctionDefinition,
) -> Unit raise {
  let { name, params, ret_ty, is_static, is_variadic, body } = func_def
  // if `static` set, we just ignore it for now
  ignore(is_static)
  if is_variadic {
    raise Unimplemented("Variadic functions are not supported yet")
  }
  let param_types : Array[&@IR.Type] = Array::new()
  let param_names : Array[String] = Array::new()
  for param in params {
    let (param_ty, param_name) = param
    let llvm_param_ty = self.ctype_to_llvm_type(param_ty)
    param_types.push(llvm_param_ty)
    param_names.push(param_name)
  }
  let llvm_ret_ty = self.ctype_to_llvm_type(ret_ty)
  let func_type = self.llvm_ctx.getFunctionType(llvm_ret_ty, param_types) catch {
    err => raise IllegalLLVMUsage("\{err}")
  }
  let llvm_func = self.llvm_mod.addFunction(func_type, name)
  self.current_func = Some(llvm_func)
  // Create entry basic block
  let entry_bb = llvm_func.addBasicBlock(name="entry")
  self.builder.setInsertPoint(entry_bb)
  // Enter new scope for function parameters
  self.enter_scope()
  for i in 0..<param_names.length() {
    let parem_name = param_names[i]
    let (param_ty, _) = params[i]
    let llvm_param = llvm_func.getArg(i).unwrap()
    llvm_param.setName(parem_name) catch {
      err => {
        let msg = "Failed to set name for parameter '\{parem_name}' of function '\{name}'"
        raise IllegalLLVMUsage("\{msg} : \{err}")
      }
    }
    // 为参数分配栈空间，便于后续作为可修改的左值处理
    let alloca = self.builder.createAlloca(param_types[i])
    let _ = self.builder.createStore(llvm_param, alloca)
    self.var_env.set(parem_name, alloca)
    self.var_types.set(parem_name, param_ty)
  }
  self.emit_compound_stmt(body)
  self.exit_scope()
  self.current_func = None
}
