///|
pub fn Context::emit_function_def(
  self : Context,
  func_def : @parser.FunctionDefinition,
) -> Unit raise CodeGenError {
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
  let llvm_func = self.llvm_mod.addFunction(func_type, name) catch {
    err =>
      raise IllegalLLVMUsage(
        "Failed to add function '\{name}' to LLVM module: \{err}",
      )
  }
  let env = self.enter_scope()
  for i in 0..<param_names.length() {
    let parem_name = param_names[i]
    let llvm_param = llvm_func.getArg(i).unwrap()
    llvm_param.setName(parem_name) catch {
      err =>
        raise IllegalLLVMUsage(
          "Failed to set name for parameter '\{parem_name}' of function '\{name}': \{err}",
        )
    }
    env.set(parem_name, llvm_param)
  }
  self.emit_compound_stmt(body)
  let _ = self.exit_scope()

}
