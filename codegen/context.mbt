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
  mut current_ret_ty : @parser.CType?
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
  let current_ret_ty = None
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
    current_ret_ty,
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
  // Typedefs are compile-time only; no LLVM emission needed.
  ignore(self)
  ignore(ty)
  ignore(name)
}

///|
fn Context::emit_initializer(
  self : Context,
  init : @parser.Initializer,
  ty : @parser.CType,
) -> &@IR.Constant raise CodeGenError {
  match init.kind {
    AssignExpr(expr) => self.emit_initializer_assign_expr(expr, ty)
    InitializerList(_) =>
      raise Unimplemented("Array/Struct initializers not supported")
    Designation(_, _) =>
      raise Unimplemented("Designated initializers not supported")
  }
}

///|
fn Context::emit_initializer_assign_expr(
  self : Context,
  expr : @parser.AssignExpr,
  ty : @parser.CType,
) -> &@IR.Constant raise CodeGenError {
  if ty.is_integral() {
    let val = expr.eval_as_int() catch {
      _ => raise SemanticError("Non-constant initializer")
    }
    let llvm_ty = self.ctype_to_llvm_type(ty) catch {
      err => raise IllegalLLVMUsage("\{err}")
    }
    match llvm_ty.tryAsIntTypeEnum() {
      Some(int_ty) => {
        let const_val = self.llvm_ctx.getConstInt64(val.to_int64())
        let width = int_ty.getBitWidth()
        let res = if width == 64 {
          const_val
        } else if width < 64 {
          const_val.trunc(int_ty.asIntegerTypeClass()) catch {
            err => raise IllegalLLVMUsage("Truncate failed: \{err}")
          }
        } else {
          const_val.sext(int_ty.asIntegerTypeClass()) catch {
            err => raise IllegalLLVMUsage("SExt failed: \{err}")
          }
        }
        res as &@IR.Constant
      }
      None => raise SemanticError("Type mismatch in initializer")
    }
  } else {
    raise Unimplemented("Only integer global initializers supported")
  }
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
  ignore(is_register)
  ignore(is_thread_local)
  let llvm_ty = self.ctype_to_llvm_type(ctype) catch {
    err => raise IllegalLLVMUsage("\{err}")
  }
  let linkage : @IR.Linkage = if is_static { Internal } else { External }
  let init_const : &@IR.Constant? = match initializer {
    Some(init) => Some(self.emit_initializer(init, ctype))
    None =>
      if is_extern {
        None
      } else {
        let zero = self.llvm_ctx.getConstZero(llvm_ty) catch {
          err => raise IllegalLLVMUsage("Zero init failed: \{err}")
        }
        Some(zero)
      }
  }
  if is_extern && init_const.is_empty() {
    match self.llvm_mod.globals.get(name) {
      Some(_) => return
      None => ()
    }
  }
  try {
    let gvar_val = match init_const {
      Some(c) => {
        let gvar = self.llvm_mod.addGlobalVariable(
          llvm_ty,
          name,
          initializer=c,
          linkage?=Some(linkage),
        )
        gvar.asValueEnum().asValueClass()
      }
      None => {
        let gvar = self.llvm_mod.addGlobalVariable(
          llvm_ty,
          name,
          linkage?=Some(linkage),
        )
        gvar.asValueEnum().asValueClass()
      }
    }
    self.var_env.set(name, gvar_val)
    self.var_types.set(name, ctype)
  } catch {
    err => raise IllegalLLVMUsage("Failed to add global variable: \{err}")
  }
}
