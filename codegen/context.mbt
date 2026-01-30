///|
pub struct Context {
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  builder : @IR.IRBuilder
  func_decls : Map[String, @parser.CType]
  func_defs : Map[String, @IR.Function]
  globals : Map[String, @IR.GlobalVariable]
  global_types : Map[String, @parser.CType]
  global_inits : Array[(String, @parser.CType, @parser.Initializer)]
  mut global_init_func : @IR.Function?
  mut global_init_emitted : Bool
  prog : @parser.Program
  mut var_env : @env.Env[String, &@IR.Value]
  mut var_types : @env.Env[String, @parser.CType]
  mut tag_env : @env.Env[String, @IR.StructType]
  mut struct_name_counter : Int
  mut current_func : @IR.Function?
  mut current_ret_ty : @parser.CType?
  break_stack : Array[@IR.BasicBlock]
  continue_stack : Array[@IR.BasicBlock]
  // switch 语句 codegen 的临时上下文栈（支持嵌套 switch 与嵌套 case label）
  switch_ctx_stack : Array[SwitchCodegenCtx]
  mut labels : Map[String, @IR.BasicBlock]
  mut label_list : Array[@IR.BasicBlock]
  label_global : Map[String, @IR.BasicBlock]
}

///|
pub struct SwitchCodegenCtx {
  switch_inst : @IR.SwitchInst
  case_map : Map[Int, @IR.BasicBlock]
  default_bb : @IR.BasicBlock
  exit_bb : @IR.BasicBlock
  cond_ty : @parser.CType
  mut active : Bool
  mut has_default : Bool
}

///|
fn Context::init_from_parse_program(ctx : @parser.Context) -> Context {
  let { source_file, prog, .. } = ctx
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule(source_file)
  llvm_mod.setDefaultDataLayout()
  let builder = llvm_ctx.createBuilder()
  let func_decls = Map::new()
  let func_defs = Map::new()
  let globals = Map::new()
  let global_types = Map::new()
  let global_inits : Array[(String, @parser.CType, @parser.Initializer)] =
    Array::new()
  let global_init_func = None
  let global_init_emitted = false
  let var_env = @env.Env::new()
  let var_types = @env.Env::new()
  let tag_env = @env.Env::new()
  let struct_name_counter = 0
  let current_func = None
  let current_ret_ty = None
  let break_stack = Array::new()
  let continue_stack = Array::new()
  let switch_ctx_stack = Array::new()
  let labels = Map::new()
  let label_list = Array::new()
  let label_global = Map::new()
  Context::{
    llvm_ctx,
    llvm_mod,
    builder,
    func_decls,
    func_defs,
    globals,
    global_types,
    global_inits,
    global_init_func,
    global_init_emitted,
    prog,
    var_env,
    var_types,
    tag_env,
    struct_name_counter,
    current_func,
    current_ret_ty,
    break_stack,
    continue_stack,
    switch_ctx_stack,
    labels,
    label_list,
    label_global,
  }
}

///|
pub fn Context::emit(self : Context) -> @IR.Module raise {
  let externals = self.prog.externals
  for ext_decl in externals {
    self.emit_external_decl(ext_decl)
  }
  self.emit_global_init_function()
  self.llvm_mod
}

///|
fn Context::ensure_global_init_func(self : Context) -> @IR.Function raise {
  match self.global_init_func {
    Some(f) => f
    None => {
      let void_ty = self.llvm_ctx.getVoidTy()
      let fty = self.llvm_ctx.getFunctionType(void_ty, Array::new(), isVarArg=false)
      let f = self.llvm_mod.addFunction(fty, "__mbtcc_global_init", linkage?=Some(InternalLinkage))
      self.global_init_func = Some(f)
      f
    }
  }
}

///|
fn Context::emit_global_init_function(self : Context) -> Unit raise {
  if self.global_init_emitted {
    return
  }
  let func = match self.global_init_func {
    Some(f) => f
    None => {
      // No main call was inserted; skip if there are no inits.
      if self.global_inits.length() == 0 {
        return
      }
      self.ensure_global_init_func()
    }
  }
  let func = self.global_init_func.unwrap()
  self.global_init_emitted = true
  let entry_bb = func.addBasicBlock(name="entry")
  let saved_func = self.current_func
  let saved_ret = self.current_ret_ty
  self.current_func = Some(func)
  self.current_ret_ty = Some(@parser.CType::void_())
  self.builder.setInsertPoint(entry_bb)
  self.enter_scope()
  for entry in self.global_inits {
    let (name, ty, init) = entry
    match self.globals.get(name) {
      Some(gv) => {
        let gptr : &@IR.Value = gv
        match init.kind {
          AssignExpr(ae) => {
            match string_literal_from_initializer(init) {
              Some((s, wide)) =>
                match ty.dataKind {
                  Array(_, _) => self.emit_string_literal_to_array(gptr, ty, s, wide)
                  _ => {
                    if ty.dataKind is Struct(_, _) || ty.dataKind is Union(_, _) {
                      let v = self.emit_assign_expr(ae)
                      self.store_aggregate_value(gptr, ty, v)
                    } else {
                      let v = self.emit_assign_expr(ae)
                      let v = self.cast_value_to_ctype(v, ae.ctype, ty)
                      self.builder.createStore(v, gptr) |> ignore
                    }
                  }
                }
              None => {
                if ty.dataKind is Struct(_, _) || ty.dataKind is Union(_, _) {
                  let v = self.emit_assign_expr(ae)
                  self.store_aggregate_value(gptr, ty, v)
                } else {
                  let v = self.emit_assign_expr(ae)
                  let v = self.cast_value_to_ctype(v, ae.ctype, ty)
                  self.builder.createStore(v, gptr) |> ignore
                }
              }
            }
          }
          InitializerList(list) =>
            self.emit_initializer_list_to_ptr(gptr, ty, list)
          Designation(desig, inner) =>
            self.emit_initializer_list_to_ptr(gptr, ty, [init])
        }
      }
      None => ()
    }
  }
  self.builder.createRetVoid() |> ignore
  self.exit_scope()
  self.current_func = saved_func
  self.current_ret_ty = saved_ret
}

///|
fn string_literal_len_in_init(init : @parser.Initializer) -> Int? {
  let mut len = 0
  let mut saw = false
  for tok in init.tokens {
    match tok.kind {
      String(s) => {
        len = len + s.length()
        saw = true
      }
      _ => return None
    }
  }
  if saw { Some(len + 1) } else { None }
}

///|
fn designator_targets_field(desig : @parser.Designator, name : String) -> Bool {
  match desig {
    Field(n) => n == name
    DesignatorList(list) =>
      if list.length() == 0 {
        false
      } else {
        match list[0] {
          Field(n) => n == name
          _ => false
        }
      }
    _ => false
  }
}

///|
fn flex_array_len_from_initializer(
  fields : Array[@parser.StructField],
  init : @parser.Initializer,
) -> Int? {
  guard fields.length() > 0 else { return None }
  let flex_idx = fields.length() - 1
  let flex_field = fields[flex_idx]
  guard flex_field.ctype.dataKind is Array(_, 0) else { return None }
  let flex_name = flex_field.name
  guard flex_name != "" else { return None }
  match init.kind {
    InitializerList(inits) => {
      let mut idx = 0
      let mut flex_init : @parser.Initializer? = None
      for item in inits {
        match item.kind {
          Designation(desig, inner) => {
            if designator_targets_field(desig, flex_name) {
              flex_init = Some(inner)
            }
          }
          _ => {
            if idx == flex_idx {
              flex_init = Some(item)
            }
            idx = idx + 1
          }
        }
      }
      match flex_init {
        Some(fi) => match fi.kind {
          InitializerList(list) => Some(list.length())
          AssignExpr(_) => string_literal_len_in_init(fi)
          _ => None
        }
        None => None
      }
    }
    _ => None
  }
}

///|
///|
fn Context::enter_scope(self : Context) -> Unit {
  let env = @env.Env::new(parent=Some(self.var_env))
  let types = @env.Env::new(parent=Some(self.var_types))
  let tags = @env.Env::new(parent=Some(self.tag_env))
  self.var_env = env
  self.var_types = types
  self.tag_env = tags
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
  guard self.tag_env.parent is Some(tags) else {
    println("Compiler ICE: Attempted to exit scope with no parent.")
    panic()
  }
  self.var_env = env
  self.var_types = types
  self.tag_env = tags
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
    VariableDeclaration(
      { dataKind: Function(_), .. } as ctype,
      is_static~,
      is_extern~,
      is_register~,
      is_thread_local~,
      name,
      _
    ) => {
      ignore(is_static)
      ignore(is_extern)
      ignore(is_register)
      ignore(is_thread_local)
      self.func_decls.set(name, ctype)
    }
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
      if name == "" {
        return
      }
      let _ = self.ctype_to_llvm_type(type_decl) catch {
        err => raise IllegalLLVMUsage("\{err}")
      }
    }
    Enum(_, _) => ()
    Union(_, _) => ()
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
        let width = int_ty.getBitWidth()
        let const_val = match width {
          1 => if val == 0 { self.llvm_ctx.getConstFalse() } else {
            self.llvm_ctx.getConstTrue()
          }
          8 => self.llvm_ctx.getConstInt8(val)
          16 => self.llvm_ctx.getConstInt16(val)
          32 => self.llvm_ctx.getConstInt32(val)
          64 => self.llvm_ctx.getConstInt64(val.to_int64())
          _ => raise IllegalLLVMUsage("Unsupported integer width: \{width}")
        }
        const_val as &@IR.Constant
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
  let mut flex_len : Int? = None
  let mut flex_elem : @parser.CType? = None
  match (ctype.dataKind, initializer) {
    (Struct(_, fields), Some(init)) => {
      flex_len = flex_array_len_from_initializer(fields, init)
      if flex_len is Some(_) {
        let last = fields[fields.length() - 1]
        match last.ctype.dataKind {
          Array(elem, 0) => flex_elem = Some(elem)
          _ => ()
        }
      }
    }
    _ => ()
  }
  let get_storage_llvm_ty = fn(self : Context) -> &@IR.Type raise {
    match (flex_len, flex_elem) {
      (Some(len), Some(elem)) if len > 0 => {
        let base_ty = self.ctype_to_llvm_type(ctype)
        let elem_ty = self.ctype_to_llvm_type(elem)
        let extra_ty = self.llvm_ctx.getArrayType(elem_ty, len)
        let elems : Array[&@IR.Type] = Array::new()
        elems.push(base_ty)
        elems.push(extra_ty)
        (self.llvm_ctx.getStructType(elems, isPacked=false) : &@IR.Type)
      }
      _ => self.ctype_to_llvm_type(ctype)
    }
  }
  // Defer tentative incomplete array definitions until a complete one appears.
  match (ctype.dataKind, initializer, is_extern) {
    (Array(_, 0), None, false) => {
      self.global_types.set(name, ctype)
      return
    }
    _ => ()
  }
  match self.globals.get(name) {
    Some(gv) => {
      self.global_types.set(name, ctype)
      if (!is_extern) || initializer is Some(_) {
        let llvm_ty = get_storage_llvm_ty(self) catch {
          err => raise IllegalLLVMUsage("\{err}")
        }
        let zero = self.const_zero_constant(llvm_ty)
        if flex_len is Some(_) {
          // Replace existing global with expanded storage for flexible array init.
          let old_name = name + "__old"
          gv.setValueName(old_name)
          let linkage : @IR.Linkage =
            if is_static { InternalLinkage } else { ExternalLinkage }
          let new_gv = self.llvm_mod.addGlobalVariable(
            llvm_ty,
            name,
            initializer=zero,
            linkage?=Some(linkage),
          )
          gv.replaceAllUsesWith(new_gv)
          self.globals.set(name, new_gv)
        } else {
          @unsafe.llvm_set_initializer(gv.getValueRef(), zero.getValueRef())
          let linkage : @IR.Linkage =
            if is_static { InternalLinkage } else { ExternalLinkage }
          let llvm_linkage = match linkage {
            ExternalLinkage => @unsafe.LLVMExternalLinkage
            InternalLinkage => @unsafe.LLVMInternalLinkage
            _ => @unsafe.LLVMExternalLinkage
          }
          @unsafe.llvm_set_linkage(gv.getValueRef(), llvm_linkage)
        }
        match initializer {
          Some(init) => self.global_inits.push((name, ctype, init))
          None => ()
        }
      }
      return
    }
    None => ()
  }
  let llvm_ty = get_storage_llvm_ty(self) catch {
    err => raise IllegalLLVMUsage("\{err}")
  }
  let linkage : @IR.Linkage =
    if is_static { InternalLinkage } else { ExternalLinkage }
  let init_const : &@IR.Constant? = match initializer {
    Some(_) => {
      // Use zero initializer and emit runtime init later.
      let zero = self.const_zero_constant(llvm_ty)
      Some(zero)
    }
    None =>
      if is_extern {
        None
      } else {
        let zero = self.const_zero_constant(llvm_ty)
        Some(zero)
      }
  }
  if is_extern && init_const is None {
    if self.globals.get(name) is Some(_) {
      return
    }
  }
  let gvar = match init_const {
    Some(c) => self.llvm_mod.addGlobalVariable(
      llvm_ty,
      name,
      initializer=c,
      linkage?=Some(linkage),
    )
    None => self.llvm_mod.addGlobalVariable(
      llvm_ty,
      name,
      linkage?=Some(linkage),
    )
  }
  self.globals.set(name, gvar)
  self.global_types.set(name, ctype)
  match initializer {
    Some(init) => self.global_inits.push((name, ctype, init))
    None => ()
  }
}
