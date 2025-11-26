///|
pub suberror CodeGenError String derive(Show)

///|
pub struct Context {
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  func_decls : Map[String, @parser.CType]
  func_defs : Map[String, @IR.Function]
  prog : @parser.Program
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
  let func_decls = Map::new()
  let func_defs = Map::new()
  Context::{ llvm_ctx, llvm_mod, func_decls, func_defs, prog }
}

///|
pub fn Context::emit(self : Context) -> Unit raise CodeGenError {
  let externals = self.prog.externals
  for ext_decl in externals {
    self.emit_external_decl(ext_decl)
  }
}

///|
pub fn Context::emit_external_decl(
  self : Context,
  ext_decl : @parser.ExternalDeclaration,
) -> Unit raise CodeGenError {
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
  raise CodeGenError("Type declaration emission not implemented yet")
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
  raise CodeGenError("Typedef emission not implemented yet")
}

///|
pub fn Context::emit_global_variable_decl(
  self : Context,
) -> Unit raise CodeGenError {
  // emit global variable declaration
  ignore(self)
  raise CodeGenError("Global variable declaration emission not implemented yet")
}

///|
pub fn Context::emit_function_def(
  self : Context,
  func_def : @parser.FunctionDefinition,
) -> Unit raise CodeGenError {
  // emit function definition
  ignore(self)
  ignore(func_def)
  raise CodeGenError("Function definition emission not implemented yet")
}
