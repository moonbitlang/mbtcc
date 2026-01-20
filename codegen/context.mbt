///|
pub struct Context {
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  builder : @IR.IRBuilder
  func_decls : Map[String, @parser.CType]
  func_defs : Map[String, @IR.Function]
  prog : @parser.Program
  mut var_env : @env.Env[String, &@IR.Value]
  mut var_types : @env.Env[String, @parser.CType]
  mut current_func : @IR.Function?
  break_stack : Array[@IR.BasicBlock]
  continue_stack : Array[@IR.BasicBlock]
  // switch 语句 codegen 的临时上下文栈（支持嵌套 switch 与嵌套 case label）
  switch_ctx_stack : Array[SwitchCodegenCtx]
  mut labels : Map[String, @IR.BasicBlock]
}

///|
pub struct SwitchCodegenCtx {
  switch_inst : @IR.SwitchInst
  case_map : Map[Int, @IR.BasicBlock]
  default_bb : @IR.BasicBlock
  exit_bb : @IR.BasicBlock
  mut active : Bool
  mut has_default : Bool
}

///|
fn Context::init_from_parse_program(ctx : @parser.Context) -> Context {
  let { source_file, prog, .. } = ctx
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule(source_file)
  let builder = llvm_ctx.createBuilder()
  let func_decls = Map::new()
  let func_defs = Map::new()
  let var_env = @env.Env::new()
  let var_types = @env.Env::new()
  let current_func = None
  let break_stack = Array::new()
  let continue_stack = Array::new()
  let switch_ctx_stack = Array::new()
  let labels = Map::new()
  Context::{
    llvm_ctx,
    llvm_mod,
    builder,
    func_decls,
    func_defs,
    prog,
    var_env,
    var_types,
    current_func,
    break_stack,
    continue_stack,
    switch_ctx_stack,
    labels,
  }
}

///|
pub fn Context::emit(self : Context) -> @IR.Module raise {
  let externals = self.prog.externals
  for ext_decl in externals {
    self.emit_external_decl(ext_decl)
  }
  self.llvm_mod
}

///|
fn Context::enter_scope(self : Context) -> Unit {
  let env = @env.Env::new(parent=Some(self.var_env))
  let types = @env.Env::new(parent=Some(self.var_types))
  self.var_env = env
  self.var_types = types
}

///|
fn Context::exit_scope(self : Context) -> Unit {
  guard self.var_env.parent is Some(env) else {
    println("Compiler ICE: Attempted to exit scope with no parent.")
    panic()
  }
  guard self.var_types.parent is Some(types) else {
    println("Compiler ICE: Attempted to exit scope with no parent.")
    panic()
  }
  self.var_env = env
  self.var_types = types
}

///|
/// Get or declare a function in the LLVM module
/// If the function is already declared, return it
/// Otherwise, declare it based on the function type from func_decls
fn Context::get_or_declare_function(
  self : Context,
  func_name : String,
) -> @IR.Function raise {
  match self.llvm_mod.getFunction(func_name) {
    Some(f) => f
    None => self.declare_function(func_name)
  }
}

///|
fn Context::declare_function(
  self : Context,
  func_name : String,
) -> @IR.Function raise {
  guard self.func_decls.get(func_name) is Some(func_type) else {
    raise SemanticError("Undeclared function '\{func_name}'")
  }
  guard func_type.dataKind is Function(params, ret_ty, is_variadic~) else {
    raise SemanticError("'\{func_name}' is not a function")
  }
  let param_types : Array[&@IR.Type] = Array::new()
  for param in params {
    let (param_ty, _) = param
    let llvm_param_ty = self.ctype_to_llvm_type(param_ty)
    param_types.push(llvm_param_ty)
  }
  let llvm_ret_ty = self.ctype_to_llvm_type(ret_ty)
  let func_type = self.llvm_ctx.getFunctionType(
    llvm_ret_ty,
    param_types,
    isVarArg=is_variadic,
  )
  self.llvm_mod.addFunction(func_type, func_name)
}

///|
pub fn Context::emit_external_decl(
  self : Context,
  ext_decl : @parser.ExternalDeclaration,
) -> Unit raise {
  match ext_decl.kind {
    Declaration(decl) => self.emit_global_decl(decl)
    FunctionDefinition(func_def) => self.emit_function_def(func_def)
  }
}

///|
pub fn Context::emit_global_decl(
  self : Context,
  decl : @parser.Declaration,
) -> Unit raise CodeGenError {
  // emit global variable declaration
  match decl.kind {
    // type declaration, e.g. `struct Point { ... };`
    TypeDeclaration(type_decl) => self.emit_type_decl(type_decl)
    // typedef declaration, e.g. `typedef int MyInt;`
    TypeDef(ty, name) => self.emit_typedef(ty, name)
    // Function declaration (e.g., `int foo();`)
    // We don't need to emit anything for function declarations
    // They will be emitted when we encounter function definitions or calls
    VariableDeclaration({ dataKind: Function(_), .. } as ctype, name, _, ..) =>
      self.func_decls.set(name, ctype)
    // variable declaration
    VariableDeclaration(
      ctype,
      is_static~,
      is_extern~,
      is_register~,
      is_thread_local~,
      name,
      initializer
    ) =>
      self.emit_global_variable_decl(
        ctype,
        name,
        initializer,
        is_static~,
        is_extern~,
        is_register~,
        is_thread_local~,
      )
  }
}

///|
pub fn Context::emit_type_decl(
  self : Context,
  type_decl : @parser.CType,
) -> Unit raise CodeGenError {
  match type_decl.dataKind {
    Struct(name, fields) => {
      if name != "" {
        match self.llvm_ctx.getStructTypeByName(name) {
          Some(_) => return
          None => ()
        }
      }
      let elem_tys : Array[&@IR.Type] = Array::new()
      for f in fields {
        let { ctype, .. } = f
        let llvm_ty = self.ctype_to_llvm_type(ctype) catch {
          err => raise IllegalLLVMUsage("\{err}")
        }
        elem_tys.push(llvm_ty)
      }
      let _ = self.llvm_ctx.getStructType(elem_tys, name~, isPacked=false) catch {
        err => raise IllegalLLVMUsage("\{err}")
      }

    }
    _ => raise Unimplemented("Type declaration emission not implemented yet")
  }
}

///|
pub fn Context::emit_typedef(
  self : Context,
  ty : @parser.CType,
  name : String,
) -> Unit raise CodeGenError {
  // emit typedef declaration
  ignore(self)
  ignore(ty)
  ignore(name)
  raise Unimplemented("Typedef emission not implemented yet")
}

///|
pub fn Context::emit_global_variable_decl(
  self : Context,
  ctype : @parser.CType,
  name : String,
  initializer : @parser.Initializer?,
  is_static~ : Bool,
  is_extern~ : Bool,
  is_register~ : Bool,
  is_thread_local~ : Bool,
) -> Unit raise CodeGenError {
  // emit global variable declaration
  ignore(self)
  ignore(ctype)
  ignore(name)
  ignore(initializer)
  ignore(is_static)
  ignore(is_extern)
  ignore(is_register)
  ignore(is_thread_local)
  raise Unimplemented(
    "Global variable declaration emission not implemented yet",
  )
}
