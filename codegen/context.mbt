///|
pub struct Context {
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  builder : @IR.IRBuilder
  func_decls : Map[String, @parser.CType]
  func_defs : Map[String, @IR.Function]
  prog : @parser.Program
  var_env : @env.Env[String, &@IR.Value]
  current_func : @IR.Function?
}

///|
pub fn Context::init_from_parse_program(ctx : @parser.Context) -> Context {
  let { source_file, prog, .. } = ctx
  guard !prog.is_empty() else {
    println("Compiler ICE: empty program in Context::from_parse_program")
    panic()
  }
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule(source_file)
  let builder = llvm_ctx.createBuilder()
  let func_decls = Map::new()
  let func_defs = Map::new()
  let var_env = @env.Env::new()
  let current_func = None
  Context::{
    llvm_ctx,
    llvm_mod,
    builder,
    func_decls,
    func_defs,
    prog,
    var_env,
    current_func,
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
fn Context::enter_scope(self : Context) -> @env.Env[String, &@IR.Value] {
  @env.Env::new(parent=Some(self.var_env))
}

///|
fn Context::exit_scope(self : Context) -> @env.Env[String, &@IR.Value] {
  match self.var_env.parent {
    Some(parent_env) => parent_env
    None => {
      println(
        "Compiler ICE: Attempted to exit scope with no parent in Context::exit_scope",
      )
      panic()
    }
  }
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
    // variable declaration, e.g. `int x;`
    VariableDeclaration(_) => self.emit_global_variable_decl()
  }
}

///|
pub fn Context::emit_type_decl(
  self : Context,
  type_decl : @parser.CType,
) -> Unit raise CodeGenError {
  // emit type declaration
  ignore(self)
  ignore(type_decl)
  raise Unimplemented("Type declaration emission not implemented yet")
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
) -> Unit raise CodeGenError {
  // emit global variable declaration
  ignore(self)
  raise Unimplemented(
    "Global variable declaration emission not implemented yet",
  )
}
