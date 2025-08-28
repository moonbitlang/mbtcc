///|
traitalias @IR.Type as LLVMType

///|
traitalias @IR.Value as LLVMValue

///|
pub enum Type {
  Void
  Int(Int) // Bitwidth, 1, 8, 16, 32, 64
  UInt(Int)
  FP(Int) // Bitwidth, 32, 64
  Ptr(Type)
  Array(Type, Int) // Element type, size
  Struct(Array[Type])
  Union(Array[Type])
  Enum(Array[(String, Int64)])
} derive(Show, Eq)

///|
fn CodeGenContext::convert_type_to_llvm(
  self : Self,
  ty : Type,
) -> &LLVMType raise CodeGenError {
  match ty {
    Void => self.llvm_ctx.getVoidTy() as &LLVMType
    Int(1) => self.llvm_ctx.getInt1Ty()
    Int(8) => self.llvm_ctx.getInt8Ty()
    Int(16) => self.llvm_ctx.getInt16Ty()
    Int(32) => self.llvm_ctx.getInt32Ty()
    Int(64) => self.llvm_ctx.getInt64Ty()
    Int(_) => self.llvm_ctx.getInt32Ty() // Default to i32 for unsupported widths
    UInt(1) => self.llvm_ctx.getInt1Ty()
    UInt(8) => self.llvm_ctx.getInt8Ty()
    UInt(16) => self.llvm_ctx.getInt16Ty()
    UInt(32) => self.llvm_ctx.getInt32Ty()
    UInt(64) => self.llvm_ctx.getInt64Ty()
    UInt(_) => self.llvm_ctx.getInt32Ty() // Default to i32 for unsupported widths
    FP(32) => self.llvm_ctx.getFloatTy()
    FP(64) => self.llvm_ctx.getDoubleTy()
    FP(_) => self.llvm_ctx.getDoubleTy() // Default to double for unsupported widths
    Ptr(_) => self.llvm_ctx.getPtrTy()
    Array(elem_type, size) => {
      let element_llvm_type = self.convert_type_to_llvm(elem_type)
      self.llvm_ctx.getArrayType(element_llvm_type, size) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    }
    Struct(_) =>
      raise CodeGenError::UnSupportFeature("Struct types not implemented yet")
    Union(_) =>
      raise CodeGenError::UnSupportFeature("Union types not implemented yet")
    Enum(_) =>
      raise CodeGenError::UnSupportFeature("Enum types not implemented yet")
  }
}

///|
pub suberror CodeGenError {
  UnSupportFeature(String)
  LLVMError(Error)
} derive(Show)

///|
struct CodeGenContext {
  external_decls : Array[ExternalDeclaration]
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  function_env : Env[@IR.Function] // Global function symbol table
  function_sig_env : Env[(Type, Array[(String, Type)])] // Function signature table: (return_type, parameters)
  typedef_env : Env[Type] // Type alias symbol table
}

///|
pub fn CodeGenContext::dump(self : Self) -> Unit {
  self.llvm_mod.dump()
}

///|
pub fn CodeGenContext::from_parser(ctx : ParserContext) -> CodeGenContext {
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule("demo")
  let function_env = Env::new()
  let function_sig_env = Env::new()
  let typedef_env = Env::new()
  CodeGenContext::{
    external_decls: ctx.external_decls,
    llvm_ctx,
    llvm_mod,
    function_env,
    function_sig_env,
    typedef_env,
  }
}

///|
pub fn CodeGenContext::analysis_declspecs(
  self : Self,
  declspecs : Array[DeclSpec],
) -> Type raise CodeGenError {
  let mut is_signed = true
  let mut base_type : Type? = None
  let mut is_long = false
  let mut is_long_long = false
  let mut is_short = false
  let mut is_unsigned = false
  for declspec in declspecs {
    match declspec {
      TypeSpec(type_spec) =>
        match type_spec {
          Void => base_type = Some(Void)
          Char => base_type = Some(Int(8))
          Short => is_short = true
          Int => base_type = Some(Int(32))
          Long => if is_long { is_long_long = true } else { is_long = true }
          Float => base_type = Some(FP(32))
          Double => base_type = Some(FP(64))
          Signed => is_signed = true
          Unsigned => {
            is_signed = false
            is_unsigned = true
          }
          Bool => base_type = Some(Int(1))
          Complex =>
            raise CodeGenError::UnSupportFeature("Complex types not supported")
          Atomic(_) =>
            raise CodeGenError::UnSupportFeature("Atomic types not supported")
          StructSpec(_) =>
            raise CodeGenError::UnSupportFeature("Struct specs not supported")
          UnionSpec(_) =>
            raise CodeGenError::UnSupportFeature("Union specs not supported")
          EnumSpec(_) => base_type = Some(Enum([]))
          TypedefName(typedef_name) =>
            match self.typedef_env.get(typedef_name) {
              Some(typedef_type) => base_type = Some(typedef_type)
              None =>
                raise CodeGenError::UnSupportFeature(
                  "Undefined typedef: \{typedef_name}",
                )
            }
        }
      StorageClassSpec(_) =>
        // Storage class doesn't affect type
        ()
      TypeQualifier(_) =>
        // Type qualifiers don't affect basic type representation
        ()
      FunctionSpec(_) =>
        // Function specs don't affect type
        ()
      AlignmentSpec(_) =>
        // Alignment specs don't affect type
        ()
    }
  }

  // Determine final type based on parsed information
  match base_type {
    Some(ty) =>
      match ty {
        Int(width) => {
          let final_width = if is_long_long {
            64 // long long is always 64-bit
          } else if is_long {
            64 // long is 64-bit on most systems
          } else if is_short {
            16
          } else {
            width
          }
          if is_unsigned {
            UInt(final_width)
          } else {
            Int(final_width)
          }
        }
        FP(width) =>
          if is_long && width == 64 {
            FP(128) // long double (though we map to 64 for simplicity)
          } else {
            FP(width)
          }
        _ => ty
      }
    None =>
      // Default type when no explicit type is given
      if is_long_long {
        if is_unsigned {
          UInt(64)
        } else {
          Int(64)
        }
      } else if is_long {
        if is_unsigned {
          UInt(64)
        } else {
          Int(64)
        }
      } else if is_short {
        if is_unsigned {
          UInt(16)
        } else {
          Int(16)
        }
      } else if is_unsigned {
        UInt(32)
      } else {
        Int(32) // Default to int
      }
  }
}

///|
pub fn CodeGenContext::run(self : Self) -> Unit raise {
  for decl in self.external_decls {
    self.emit_external_decl(decl)
  }
}

///|
pub fn CodeGenContext::emit_external_decl(
  self : Self,
  decl : ExternalDeclaration,
) -> Unit raise {
  match decl {
    FunctionDefinition(func_def) => self.emit_function_definition(func_def)
    Declaration(decl) => self.emit_declaration(decl)
  }
}

///|
fn CodeGenContext::analysis_param_declarator(
  self : Self,
  decl : Declarator,
  basic_type : Type,
) -> (Type, String) raise CodeGenError {
  let param_name = decl.get_ident()

  // Handle pointer declarators
  let mut param_type = match decl.pointer {
    Some(_pointer) =>
      // For now, just create a pointer to the basic type
      // TODO: Handle multiple levels of pointers
      Ptr(basic_type)
    None => basic_type
  }

  // Handle direct declarator modifications
  param_type = match decl.directDeclarator {
    Identifier(_) => param_type
    Parenthesized(inner_decl) => {
      // Recursively handle parenthesized declarator
      let (inner_type, _) = self.analysis_param_declarator(
        inner_decl, basic_type,
      )
      inner_type
    }
    Array(_, _, size_expr) =>
      // Array parameter - in C, array parameters are treated as pointers
      Ptr(param_type)
    StaticArray(_, _, _) =>
      // Static array - also treated as pointer in parameters
      Ptr(param_type)
    VallengthArray(_, _) =>
      // Variable length array - also treated as pointer
      Ptr(param_type)
    FunctionDecl(_, _) =>
      // Function pointer parameter
      // TODO: Implement proper function pointer type
      Ptr(basic_type) // Placeholder
    FunctionPtr(_, _) =>
      // Function pointer with identifier list
      Ptr(basic_type) // Placeholder
    BitField(_, _) =>
      // Bit fields are not valid in parameter declarations
      raise CodeGenError::UnSupportFeature(
        "Bit fields are not allowed in parameter declarations.",
      )
  }
  (param_type, param_name)
}

///|
fn CodeGenContext::analysis_typename(
  self : Self,
  type_name : TypeName,
) -> Type raise CodeGenError {
  // Convert TypeSpecOrQualifier to DeclSpec for reuse of analysis_declspecs
  let declspecs : Array[DeclSpec] = []
  for spec in type_name.specifiers {
    match spec {
      TypeSpec(type_spec) => declspecs.push(DeclSpec::TypeSpec(type_spec))
      TypeQualifier(type_qual) =>
        declspecs.push(DeclSpec::TypeQualifier(type_qual))
    }
  }

  // Get base type from specifiers
  let mut base_type = self.analysis_declspecs(declspecs)

  // Handle abstract declarator modifications
  match type_name.abstract_declarator {
    Some(abstract_decl) =>
      base_type = self.analysis_abstract_declarator(abstract_decl, base_type)
    None => ()
  }
  base_type
}

///|
fn CodeGenContext::analysis_abstract_declarator(
  self : Self,
  abstract_decl : AbstractDeclarator,
  base_type : Type,
) -> Type raise CodeGenError {
  let mut result_type = base_type

  // Handle pointer in abstract declarator
  match abstract_decl.pointer {
    Some(_pointer) => result_type = Ptr(result_type)
    None => ()
  }

  // Handle direct abstract declarator
  match abstract_decl.directAbstractDeclarator {
    Some(direct_abstract_decl) =>
      result_type = self.analysis_direct_abstract_declarator(
        direct_abstract_decl, result_type,
      )
    None => ()
  }
  result_type
}

///|
fn CodeGenContext::analysis_direct_abstract_declarator(
  self : Self,
  direct_abstract_decl : DirectAbstractDeclarator,
  base_type : Type,
) -> Type raise CodeGenError {
  match direct_abstract_decl {
    FuncDecl(inner_opt, _param_type_list) =>
      raise CodeGenError::UnSupportFeature(
        "Function declarations in abstract declarators not supported",
      )
    ArrayDecl(inner_opt, is_static~, _type_quals, _size_expr) =>
      raise CodeGenError::UnSupportFeature(
        "Array declarations in abstract declarators not supported",
      )
    InCompleteArray(inner_opt) =>
      raise CodeGenError::UnSupportFeature(
        "Incomplete arrays in abstract declarators not supported",
      )
    FuncPtr(inner_opt, _abstract_decl) =>
      raise CodeGenError::UnSupportFeature(
        "Function pointers in abstract declarators not supported",
      )
  }
}

///|
pub fn CodeGenContext::emit_declaration(
  self : Self,
  decl : Declaration,
) -> Unit raise CodeGenError {
  match decl {
    Decl(declspecs, inits) => {
      // Check if this is a typedef declaration
      let is_typedef = declspecs
        .iter()
        .any(fn(spec) {
          match spec {
            StorageClassSpec(StorageClassSpec::Typedef) => true
            _ => false
          }
        })
      if is_typedef {
        // Handle typedef declaration
        // Extract the base type from non-typedef declspecs
        let base_declspecs = declspecs.filter(fn(spec) {
          match spec {
            StorageClassSpec(StorageClassSpec::Typedef) => false
            _ => true
          }
        })
        let base_type = self.analysis_declspecs(base_declspecs)

        // Process each init declarator to get the typedef name
        for init_decl in inits {
          let { declarator, initializer } = init_decl
          if initializer is Some(_) {
            raise CodeGenError::UnSupportFeature(
              "Typedef declarations cannot have initializers",
            )
          }
          let typedef_name = declarator.get_ident()
          // For now, we only support simple typedef (no pointers/arrays)
          let typedef_type = match declarator.pointer {
            Some(_) => Ptr(base_type)
            None => base_type
          }

          // Add to typedef environment
          self.typedef_env.set(typedef_name, typedef_type)
        }
      } else {
        // Handle regular declarations (variables and function declarations)
        let base_type = self.analysis_declspecs(declspecs)
        for init_decl in inits {
          let { declarator, initializer } = init_decl

          // Check if this is a function declaration
          let is_function_decl = match declarator.directDeclarator {
            FunctionDecl(_, _) | FunctionPtr(_, _) => true
            _ => false
          }
          if is_function_decl {
            // Handle function declaration
            if initializer is Some(_) {
              raise CodeGenError::UnSupportFeature(
                "Function declarations cannot have initializers",
              )
            }
            let (ret_type, func_name, params) = self.analysis_func_declarator(
              declarator, base_type,
            )

            // Create LLVM function type
            let param_types : Array[&LLVMType] = Array::new()
            for param in params {
              let (_, param_type) = param
              let llvm_param_type = self.convert_type_to_llvm(param_type)
              param_types.push(llvm_param_type)
            }
            let llvm_ret_type = self.convert_type_to_llvm(ret_type)
            let func_type = self.llvm_ctx.getFunctionType(
              llvm_ret_type, param_types,
            ) catch {
              err => raise CodeGenError::LLVMError(err)
            }

            // Declare the function (extern if not already defined)
            let llvm_func = self.llvm_mod.addFunction(func_type, func_name) catch {
              err => raise CodeGenError::LLVMError(err)
            }

            // Add function to global function environment
            self.function_env.set(func_name, llvm_func)
            // Store function signature for type checking during calls
            self.function_sig_env.set(func_name, (ret_type, params))
          } else {
            // Handle variable declaration
            // For now, skip variable declarations at global scope
            // TODO: Implement global variable declarations
            ()
          }
        }
      }
    }
  }
}

///|
struct FuncCodeGenContext {
  global_ctx : CodeGenContext
  func_def : FunctionDefinition
  func_value : @IR.Function
  var_env : Env[(Type, &LLVMValue, Bool)] // Type, alloca, is_array
  builder : @IR.IRBuilder
  return_type : Type // Function return type for type checking
}

///|
pub fn CodeGenContext::emit_function_definition(
  self : Self,
  func_def : FunctionDefinition,
) -> Unit raise {
  if !func_def.kr_declarations.is_empty() {
    raise CodeGenError::UnSupportFeature(
      "K&R style function definitions are not supported.",
    )
  }
  let basic_type = self.analysis_declspecs(func_def.declSpecs)
  let (ret_type, func_name, params) = self.analysis_func_declarator(
    func_def.declarator,
    basic_type,
  )
  let param_types : Array[&LLVMType] = Array::new()
  for param in params {
    let (_, param_type) = param
    let llvm_param_type = self.convert_type_to_llvm(param_type)
    param_types.push(llvm_param_type)
  }
  let llvm_ret_type = self.convert_type_to_llvm(ret_type)
  let func_type = self.llvm_ctx.getFunctionType(llvm_ret_type, param_types) catch {
    err => raise CodeGenError::LLVMError(err)
  }
  let llvm_func = self.llvm_mod.addFunction(func_type, func_name) catch {
    err => raise CodeGenError::LLVMError(err)
  }
  // Add function to global function environment
  self.function_env.set(func_name, llvm_func)
  // Store function signature for type checking during calls
  self.function_sig_env.set(func_name, (ret_type, params))
  let var_env : Env[(Type, &LLVMValue, Bool)] = Env::new()
  let builder = self.llvm_ctx.createBuilder()

  // Create entry block first for allocas
  let entry_bb = llvm_func.addBasicBlock(name="entry")
  builder.setInsertPoint(entry_bb)

  // For parameters, create allocas and store parameter values for consistency
  for i in 0..<params.length() {
    let (param_name, param_type) = params[i]
    let llvm_param = llvm_func.getArg(i).unwrap()
    let llvm_type = self.convert_type_to_llvm(param_type)
    let alloca = builder.createAlloca(llvm_type, name=param_name)
    ignore(builder.createStore(llvm_param, alloca))
    var_env.set(param_name, (param_type, alloca, false)) // Parameters are not arrays
  }
  let func_codegen = FuncCodeGenContext::{
    global_ctx: self,
    func_def,
    func_value: llvm_func,
    var_env,
    builder,
    return_type: ret_type,
  }
  func_codegen.emit_function_body()
}

///|
fn CodeGenContext::analysis_func_declarator(
  self : Self,
  decl : Declarator,
  basic_type : Type,
) -> (Type, String, Array[(String, Type)]) raise CodeGenError {
  let ret_type = match decl.pointer {
    Some(_) => Ptr(basic_type)
    None => basic_type
  }
  let (func_name, params) = match decl.directDeclarator {
    FunctionDecl(Identifier(func_name), param_type_list) => {
      let func_params : Array[(String, Type)] = []
      let { params, variadic } = param_type_list
      if variadic {
        raise CodeGenError::UnSupportFeature(
          "Variadic functions are not supported.",
        )
      }
      for i, param in params.iter2() {
        let { decl_specs, declarator } = param
        let param_type = self.analysis_declspecs(decl_specs)
        let (final_param_type, param_name) = match declarator {
          Some(declarator) =>
            match declarator {
              Declarator(declarator) =>
                self.analysis_param_declarator(declarator, param_type)
              AbstractDeclarator(_) =>
                // For abstract declarators, generate a default parameter name
                (param_type, "param_\{i}")
            }
          None =>
            // For parameters without declarators, generate a default parameter name
            (param_type, "param_\{i}")
        }
        func_params.push((param_name, final_param_type))
      }
      (func_name, func_params)
    }
    // Handle FunctionPtr case - for functions like main() with empty parameter list
    FunctionPtr(Identifier(func_name), params_list) => {
      let func_params : Array[(String, Type)] = []
      // If params_list is empty, it's a function with no parameters
      // Otherwise, it's a K&R style function with parameter names
      if !params_list.is_empty() {
        raise CodeGenError::UnSupportFeature(
          "K&R style function parameter lists are not supported.",
        )
      }
      (func_name, func_params)
    }
    FunctionDecl(nested_decl, param_type_list) => {
      // Handle nested function declarators
      let func_name = nested_decl.get_ident()
      let func_params : Array[(String, Type)] = []
      let { params, variadic } = param_type_list
      if variadic {
        raise CodeGenError::UnSupportFeature(
          "Variadic functions are not supported.",
        )
      }
      for i, param in params.iter2() {
        let { decl_specs, declarator } = param
        let param_type = self.analysis_declspecs(decl_specs)
        let (final_param_type, param_name) = match declarator {
          Some(declarator) =>
            match declarator {
              Declarator(declarator) =>
                self.analysis_param_declarator(declarator, param_type)
              AbstractDeclarator(_) =>
                // For abstract declarators, generate a default parameter name
                (param_type, "param_\{i}")
            }
          None =>
            // For parameters without declarators, generate a default parameter name
            (param_type, "param_\{i}")
        }
        func_params.push((param_name, final_param_type))
      }
      (func_name, func_params)
    }
    FunctionPtr(nested_decl, params_list) => {
      // Handle nested function pointers
      let func_name = nested_decl.get_ident()
      let func_params : Array[(String, Type)] = []
      if !params_list.is_empty() {
        raise CodeGenError::UnSupportFeature(
          "K&R style function parameter lists are not supported.",
        )
      }
      (func_name, func_params)
    }
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only function declarators are supported.",
      )
  }
  (ret_type, func_name, params)
}

///|
fn FuncCodeGenContext::emit_function_body(self : Self) -> Unit raise {
  let compound_statement = self.func_def.body
  // Entry block and insert point are already set up
  self.emit_compound_statement(compound_statement)
}

///|
fn FuncCodeGenContext::emit_compound_statement(
  self : Self,
  comp_stmt : CompoundStatement,
) -> Unit raise {
  let { items } = comp_stmt
  for item in items {
    match item {
      Statement(stmt) => self.emit_statement(stmt)
      Declaration(decl) => self.emit_declaration(decl)
    }
  }
}

///|
fn FuncCodeGenContext::emit_statement(
  self : Self,
  stmt : Statement,
) -> Unit raise {
  match stmt {
    Empty => ()
    LabeledStatement(label) =>
      raise CodeGenError::UnSupportFeature("Labeled statements not supported")
    ExpressionStatement(expr) => self.emit_expr_stat(expr)
    SelectionStatement(sel_stmt) => self.emit_selection_statement(sel_stmt)
    IterationStatement(iter_stmt) => self.emit_iteration_statement(iter_stmt)
    JumpStatement(jump_stmt) => self.emit_jump_statement(jump_stmt)
    CompoundStatement(comp_stmt) => self.emit_compound_statement(comp_stmt)
  }
}

///|
fn FuncCodeGenContext::emit_expr(
  self : Self,
  expr : Expr,
) -> (Type, &LLVMValue) raise {
  let { exprs } = expr
  let first_assign_expr = exprs[0]
  let (ty, val) = self.emit_assign_expr(first_assign_expr)
  for i in 1..<exprs.length() {
    let assign_expr = exprs[i]
    let _ = self.emit_assign_expr(assign_expr)

  }
  (ty, val)
}

///|
fn FuncCodeGenContext::emit_expr_stat(
  self : Self,
  expr_stmt : Expr,
) -> Unit raise {
  let { exprs } = expr_stmt
  for assign_expr in exprs {
    let _ = self.emit_assign_expr(assign_expr)

  }
}

///|
fn FuncCodeGenContext::emit_assign_expr(
  self : Self,
  assign_expr : AssignExpr,
) -> (Type, &LLVMValue) raise {
  match assign_expr {
    Conditional(cond) => self.emit_conditional_expr(cond)
    Assign(left, op, expr) => {
      let (lty, left) = self.emit_unary_expr_as_lvalue(left)
      let (rty, right) = self.emit_assign_expr(expr)
      let right = if lty != rty {
        self.emit_cast(from_type=rty, to_type=lty, right)
      } else {
        right
      }
      let val = match op {
        Assign => {
          ignore(self.builder.createStore(right, left))
          right
        }
        AddAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createAdd(left_val, right)
            FP(_) => self.builder.createFAdd(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for AddAssign.",
              )
          }
          ignore(self.builder.createStore(result, left))
          result
        }
        SubAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createSub(left_val, right)
            FP(_) => self.builder.createFSub(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for SubAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        MultAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createMul(left_val, right)
            FP(_) => self.builder.createFMul(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for MultAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        DivAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) => self.builder.createSDiv(left_val, right)
            UInt(_) => self.builder.createUDiv(left_val, right)
            FP(_) => self.builder.createFDiv(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for DivAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        ModAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) => self.builder.createSRem(left_val, right)
            UInt(_) => self.builder.createURem(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for ModAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        AndAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createAnd(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for AndAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        OrAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createOr(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for OrAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        BitwiseAndAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createAnd(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for BitAndAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        BitwiseOrAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createOr(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for BitOrAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        BitwiseXorAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createXor(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for BitXorAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        LeftShiftAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createShl(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for LeftShiftAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
        RightShiftAssign => {
          let left_type = self.global_ctx.convert_type_to_llvm(lty)
          let left_val = self.builder.createLoad(left_type, left)
          let result = match lty {
            Int(_) => self.builder.createAShr(left_val, right)
            UInt(_) => self.builder.createLShr(left_val, right)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for RightShiftAssign.",
              )
          }
          self.builder.createStore(result, left)
        }
      }
      (lty, val)
    }
  }
}

///|
pub fn FuncCodeGenContext::emit_cast(
  self : Self,
  from_type~ : Type,
  to_type~ : Type,
  value : &LLVMValue,
) -> &LLVMValue raise {
  if from_type == to_type {
    return value
  }
  match (from_type, to_type) {
    // Pointer to integer conversion
    (Ptr(_), Int(width)) => {
      let int_type : &@IR.IntegerType = match width {
        8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
        16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
        32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
        _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
      }
      self.builder.createPtrToInt(value, int_type)
    }

    // Integer to pointer conversion  
    (Int(_), Ptr(_)) | (UInt(_), Ptr(_)) => self.builder.createIntToPtr(value)

    // Float to integer conversion
    (FP(_), Int(width)) => {
      let int_type : &@IR.IntegerType = match width {
        8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
        16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
        32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
        _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
      }
      self.builder.createFPToSI(value, int_type)
    }

    // Float to unsigned integer conversion
    (FP(_), UInt(width)) => {
      let int_type : &@IR.IntegerType = match width {
        8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
        16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
        32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
        _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
      }
      self.builder.createFPToUI(value, int_type)
    }

    // Integer to float conversion
    (Int(_), FP(width)) => {
      let fp_type : &@IR.FPType = match width {
        32 => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
        64 => self.global_ctx.llvm_ctx.getDoubleTy() as &@IR.FPType
        _ => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
      }
      self.builder.createSIToFP(value, fp_type)
    }

    // Unsigned integer to float conversion
    (UInt(_), FP(width)) => {
      let fp_type : &@IR.FPType = match width {
        32 => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
        64 => self.global_ctx.llvm_ctx.getDoubleTy() as &@IR.FPType
        _ => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
      }
      self.builder.createUIToFP(value, fp_type)
    }

    // Signed integer extension/truncation
    (Int(from_width), Int(to_width)) =>
      if from_width < to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        // For boolean (i1) to integer conversion, use zero extension
        if from_width == 1 {
          self.builder.createZExt(value, int_type)
        } else {
          self.builder.createSExt(value, int_type)
        }
      } else if from_width > to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createTrunc(value, int_type)
      } else {
        value
      }

    // Unsigned integer extension/truncation
    (UInt(from_width), UInt(to_width)) =>
      if from_width < to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createZExt(value, int_type)
      } else if from_width > to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createTrunc(value, int_type)
      } else {
        value
      }

    // Signed to unsigned integer conversion
    (Int(from_width), UInt(to_width)) =>
      if from_width < to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createSExt(value, int_type)
      } else if from_width > to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createTrunc(value, int_type)
      } else {
        value
      }

    // Unsigned to signed integer conversion
    (UInt(from_width), Int(to_width)) =>
      if from_width < to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createZExt(value, int_type)
      } else if from_width > to_width {
        let int_type : &@IR.IntegerType = match to_width {
          8 => self.global_ctx.llvm_ctx.getInt8Ty() as &@IR.IntegerType
          16 => self.global_ctx.llvm_ctx.getInt16Ty() as &@IR.IntegerType
          32 => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
          64 => self.global_ctx.llvm_ctx.getInt64Ty() as &@IR.IntegerType
          _ => self.global_ctx.llvm_ctx.getInt32Ty() as &@IR.IntegerType
        }
        self.builder.createTrunc(value, int_type)
      } else {
        value
      }

    // Float to float conversion (float <-> double)
    (FP(from_width), FP(to_width)) =>
      if from_width < to_width {
        // Extend float to double
        let fp_type : &@IR.FPType = match to_width {
          32 => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
          64 => self.global_ctx.llvm_ctx.getDoubleTy() as &@IR.FPType
          _ => self.global_ctx.llvm_ctx.getDoubleTy() as &@IR.FPType
        }
        self.builder.createFPExt(value, fp_type)
      } else if from_width > to_width {
        // Truncate double to float
        let fp_type : &@IR.FPType = match to_width {
          32 => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
          64 => self.global_ctx.llvm_ctx.getDoubleTy() as &@IR.FPType
          _ => self.global_ctx.llvm_ctx.getFloatTy() as &@IR.FPType
        }
        self.builder.createFPTrunc(value, fp_type)
      } else {
        value
      }

    // Pointer to pointer conversion (type cast)
    (Ptr(_), Ptr(_)) =>
      // In LLVM, all pointers have the same representation, so this is essentially a no-op
      // but we return the value to maintain type information
      value

    // For other cases that don't require conversion, return original value
    _ => value
  }
}

///|
fn FuncCodeGenContext::emit_conditional_expr(
  self : Self,
  cond_expr : ConditionalExpr,
) -> (Type, &LLVMValue) raise {
  let { expr, select } = cond_expr
  let (cond_type, cond_val) = self.emit_logical_or_expr(expr)
  if select is Some(select) {
    let cond_val = if not(cond_type is Int(1) || cond_type is UInt(1)) {
      self.emit_cast(from_type=cond_type, to_type=Int(1), cond_val)
    } else {
      cond_val
    }
    let (then_expr, else_expr) = select
    let (then_ty, then_val) = self.emit_expr(then_expr)
    let (else_ty, else_val) = self.emit_conditional_expr(else_expr)
    let then_val = if then_ty != else_ty {
      self.emit_cast(from_type=then_ty, to_type=else_ty, then_val)
    } else {
      then_val
    }
    let val = self.builder.createSelect(cond_val, then_val, else_val)
    (else_ty, val)
  } else {
    (cond_type, cond_val)
  }
}

///|
fn FuncCodeGenContext::emit_logical_or_expr(
  self : Self,
  log_or_expr : LogicalOrExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: logical_and_exprs } = log_or_expr
  let (first_ty, first_val) = self.emit_logical_and_expr(logical_and_exprs[0])
  for i in 1..<logical_and_exprs.length() {
    let (ty, val) = self.emit_logical_and_expr(logical_and_exprs[i])
    let first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }

  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_logical_and_expr(
  self : Self,
  log_and_expr : LogicalAndExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: inclusive_or_exprs } = log_and_expr
  let (first_ty, first_val) = self.emit_inclusive_or_expr(inclusive_or_exprs[0])
  for i in 1..<inclusive_or_exprs.length() {
    let (ty, val) = self.emit_inclusive_or_expr(inclusive_or_exprs[i])
    let first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }

  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_inclusive_or_expr(
  self : Self,
  incl_or_expr : InclusiveOrExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: exclusive_or_exprs } = incl_or_expr
  let (first_ty_init, first_val_init) = self.emit_exclusive_or_expr(
    exclusive_or_exprs[0],
  )
  let mut first_ty = first_ty_init
  let mut first_val = first_val_init
  for i in 1..<exclusive_or_exprs.length() {
    let (ty, val) = self.emit_exclusive_or_expr(exclusive_or_exprs[i])
    let adjusted_first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    // Perform bitwise OR operation
    let result = match first_ty {
      Int(_) | UInt(_) => self.builder.createOr(adjusted_first_val, val)
      _ =>
        raise CodeGenError::UnSupportFeature(
          "Bitwise OR not supported for type \{first_ty}",
        )
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_exclusive_or_expr(
  self : Self,
  excl_or_expr : ExclusiveOrExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: and_exprs } = excl_or_expr
  let (first_ty_init, first_val_init) = self.emit_and_expr(and_exprs[0])
  let mut first_ty = first_ty_init
  let mut first_val = first_val_init
  for i in 1..<and_exprs.length() {
    let (ty, val) = self.emit_and_expr(and_exprs[i])
    let adjusted_first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    // Perform bitwise XOR operation
    let result = match first_ty {
      Int(_) | UInt(_) => self.builder.createXor(adjusted_first_val, val)
      _ =>
        raise CodeGenError::UnSupportFeature(
          "Bitwise XOR not supported for type \{first_ty}",
        )
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_and_expr(
  self : Self,
  and_expr : AndExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: equality_exprs } = and_expr
  let (first_ty_init, first_val_init) = self.emit_equality_expr(
    equality_exprs[0],
  )
  let mut first_ty = first_ty_init
  let mut first_val = first_val_init
  for i in 1..<equality_exprs.length() {
    let (ty, val) = self.emit_equality_expr(equality_exprs[i])
    let adjusted_first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    // Perform bitwise AND operation
    let result = match first_ty {
      Int(_) | UInt(_) => self.builder.createAnd(adjusted_first_val, val)
      _ =>
        raise CodeGenError::UnSupportFeature(
          "Bitwise AND not supported for type \{first_ty}",
        )
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_equality_expr(
  self : Self,
  eq_expr : EqualityExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = eq_expr
  let (first_ty, first_val) = self.emit_relational_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1..<exprs.length() {
    let (ty, val) = self.emit_relational_expr(exprs[i])
    first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      EQ => self.builder.createICmpEQ(first_val, val)
      NE => self.builder.createICmpNE(first_val, val)
    }
    first_val = result
    first_ty = Int(1)
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_relational_expr(
  self : Self,
  rel_expr : RelationalExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = rel_expr
  let (first_ty, first_val) = self.emit_shift_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1..<exprs.length() {
    let (ty, val) = self.emit_shift_expr(exprs[i])
    first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      LT => self.builder.createICmpSLT(first_val, val)
      GT => self.builder.createICmpSGT(first_val, val)
      LE => self.builder.createICmpSLE(first_val, val)
      GE => self.builder.createICmpSGE(first_val, val)
    }
    first_val = result
    first_ty = Int(1)
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_shift_expr(
  self : Self,
  shift_expr : ShiftExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = shift_expr
  let (first_ty, first_val) = self.emit_addsub_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1..<exprs.length() {
    let (ty, val) = self.emit_addsub_expr(exprs[i])
    first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      Shl => self.builder.createShl(first_val, val)
      Shr =>
        match first_ty {
          Int(_) => self.builder.createAShr(first_val, val) // Arithmetic (signed) shift right
          UInt(_) => self.builder.createLShr(first_val, val) // Logical (unsigned) shift right
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Shift operations not supported for type \{first_ty}",
            )
        }
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_addsub_expr(
  self : Self,
  add_expr : AddSubExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = add_expr
  let (first_ty, first_val) = self.emit_mult_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1..<exprs.length() {
    let (ty, val) = self.emit_mult_expr(exprs[i])
    first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      Add =>
        match first_ty {
          Int(_) | UInt(_) => self.builder.createAdd(first_val, val)
          FP(_) => self.builder.createFAdd(first_val, val)
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Unsupported type for Plus operation.",
            )
        }
      Sub =>
        match first_ty {
          Int(_) | UInt(_) => self.builder.createSub(first_val, val)
          FP(_) => self.builder.createFSub(first_val, val)
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Unsupported type for Minus operation.",
            )
        }
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_mult_expr(
  self : Self,
  mult_expr : MultExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = mult_expr
  let (first_ty, first_val) = self.emit_cast_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1..<exprs.length() {
    let (ty, val) = self.emit_cast_expr(exprs[i])
    first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      Mult =>
        match first_ty {
          Int(_) | UInt(_) => self.builder.createMul(first_val, val)
          FP(_) => self.builder.createFMul(first_val, val)
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Unsupported type for Multiplication operation.",
            )
        }
      Div =>
        match first_ty {
          Int(_) => self.builder.createSDiv(first_val, val)
          UInt(_) => self.builder.createUDiv(first_val, val)
          FP(_) => self.builder.createFDiv(first_val, val)
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Unsupported type for Division operation.",
            )
        }
      Mod =>
        match first_ty {
          Int(_) => self.builder.createSRem(first_val, val)
          UInt(_) => self.builder.createURem(first_val, val)
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Unsupported type for Modulus operation.",
            )
        }
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_cast_expr(
  self : Self,
  cast_expr : CastExpr,
) -> (Type, &LLVMValue) raise {
  match cast_expr {
    UnaryExpr(unary_expr) => self.emit_unary_expr(unary_expr)
    Cast(type_name, expr) => {
      let ty = self.global_ctx.analysis_typename(type_name)
      let (expr_type, expr_val) = self.emit_cast_expr(expr)
      let casted_val = self.emit_cast(from_type=expr_type, to_type=ty, expr_val)
      (ty, casted_val)
    }
  }
}

///|
fn FuncCodeGenContext::emit_cast_expr_as_lvalue(
  self : Self,
  cast_expr : CastExpr,
) -> (Type, &LLVMValue) raise {
  match cast_expr {
    UnaryExpr(unary_expr) => self.emit_unary_expr_as_lvalue(unary_expr)
    Cast(type_name, expr) =>
      // For cast expressions as lvalue, we need to handle this carefully
      // For now, we'll raise an error since casting to lvalue is complex
      raise CodeGenError::UnSupportFeature(
        "Cast expressions as lvalue not supported yet",
      )
  }
}

///|
fn FuncCodeGenContext::emit_unary_expr(
  self : Self,
  unary_expr : UnaryExpr,
) -> (Type, &LLVMValue) raise {
  // Check if we have prefix increment/decrement operators
  let has_increment_decrement = unary_expr.prefix
    .iter()
    .any(fn(op) { op == PlusPlus || op == MinusMinus })
  let (expr_type_init, expr_value_init) = if has_increment_decrement {
    // For ++/-- operators, we need the lvalue (address) of the body
    match unary_expr.body {
      PostFix(postfix_expr) => self.emit_postfix_expr_as_lvalue(postfix_expr)
      UnaryOp(op, cast_expr) =>
        match op {
          Dereference => {
            let (operand_type, operand_value) = self.emit_cast_expr(cast_expr)
            match operand_type {
              Ptr(pointed_type) => (pointed_type, operand_value)
              _ =>
                raise CodeGenError::UnSupportFeature(
                  "Cannot dereference non-pointer type \{operand_type}",
                )
            }
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Only variables and dereferences can be incremented/decremented",
            )
        }
      _ =>
        raise CodeGenError::UnSupportFeature(
          "Only variables and dereferences can be incremented/decremented",
        )
    }
  } else {
    // For other operators, evaluate normally as rvalue
    self.emit_unary_expr_body(unary_expr.body)
  }
  let mut expr_type = expr_type_init
  let mut expr_value = expr_value_init

  // Apply prefix operators in reverse order (rightmost first)
  let prefix_len = unary_expr.prefix.length()
  for i in 0..<prefix_len {
    let prefix_op = unary_expr.prefix[prefix_len - 1 - i]
    match prefix_op {
      PlusPlus =>
        // Pre-increment: load, add 1, store, return new value
        match expr_type {
          Int(_) | UInt(_) => {
            // expr_value is an address for pre-increment
            let llvm_type = self.global_ctx.convert_type_to_llvm(expr_type)
            let current_val = self.builder.createLoad(llvm_type, expr_value)
            let one = match expr_type {
              Int(_) => self.global_ctx.llvm_ctx.getConstInt32(1)
              UInt(_) => self.global_ctx.llvm_ctx.getConstInt32(1)
              _ => self.global_ctx.llvm_ctx.getConstInt32(1) // Fallback
            }
            let new_val = self.builder.createAdd(current_val, one)
            ignore(self.builder.createStore(new_val, expr_value))
            expr_value = new_val
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Pre-increment not supported for type \{expr_type}",
            )
        }
      MinusMinus =>
        // Pre-decrement: load, subtract 1, store, return new value
        match expr_type {
          Int(_) | UInt(_) => {
            let llvm_type = self.global_ctx.convert_type_to_llvm(expr_type)
            let current_val = self.builder.createLoad(llvm_type, expr_value)
            let one = match expr_type {
              Int(_) => self.global_ctx.llvm_ctx.getConstInt32(1)
              UInt(_) => self.global_ctx.llvm_ctx.getConstInt32(1)
              _ => self.global_ctx.llvm_ctx.getConstInt32(1) // Fallback
            }
            let new_val = self.builder.createSub(current_val, one)
            ignore(self.builder.createStore(new_val, expr_value))
            expr_value = new_val
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Pre-decrement not supported for type \{expr_type}",
            )
        }
      Sizeof => {
        // Sizeof operator: return size in bytes as compile-time constant
        let size_bytes = match expr_type {
          Int(1) | UInt(1) => 1
          Int(8) | UInt(8) => 1
          Int(16) | UInt(16) => 2
          Int(32) | UInt(32) => 4
          Int(64) | UInt(64) => 8
          FP(32) => 4
          FP(64) => 8
          Ptr(_) => 8 // Assume 64-bit pointers
          _ => 4 // Default size
        }
        expr_value = self.global_ctx.llvm_ctx.getConstInt32(size_bytes)
        expr_type = Int(32)
      }
    }
  }
  (expr_type, expr_value)
}

///|
fn FuncCodeGenContext::emit_unary_expr_body(
  self : Self,
  unary_body : UnaryExprBody,
) -> (Type, &LLVMValue) raise {
  match unary_body {
    PostFix(postfix_expr) => self.emit_postfix_expr(postfix_expr)
    UnaryOp(op, cast_expr) =>
      match op {
        AddressOf => {
          // Address-of operator: get address of lvalue
          // We need to get the lvalue (address) of the operand
          let (lvalue_type, lvalue_addr) = self.emit_cast_expr_as_lvalue(
            cast_expr,
          )
          (Ptr(lvalue_type), lvalue_addr)
        }
        _ => {
          let (operand_type, operand_value) = self.emit_cast_expr(cast_expr)
          match op {
            AddressOf => raise CodeGenError::UnSupportFeature("Impossible case")
            Dereference =>
              // Dereference operator: load from pointer
              match operand_type {
                Ptr(pointed_type) => {
                  let llvm_type = self.global_ctx.convert_type_to_llvm(
                    pointed_type,
                  )
                  let loaded_value = self.builder.createLoad(
                    llvm_type, operand_value,
                  )
                  (pointed_type, loaded_value)
                }
                _ =>
                  raise CodeGenError::UnSupportFeature(
                    "Cannot dereference non-pointer type \{operand_type}",
                  )
              }
            Positive =>
              // Unary plus: no-op, just return the operand
              (operand_type, operand_value)
            Negative =>
              // Unary minus: negate the operand
              match operand_type {
                Int(_) | UInt(_) => {
                  let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
                  let negated = self.builder.createSub(zero, operand_value)
                  (operand_type, negated)
                }
                FP(_) => {
                  // For floating point, use FSub with zero constant
                  let zero = match operand_type {
                    FP(32) => self.global_ctx.llvm_ctx.getConstZeroFloat()
                    FP(64) => self.global_ctx.llvm_ctx.getConstZeroDouble()
                    _ => self.global_ctx.llvm_ctx.getConstZeroFloat() // Fallback
                  }
                  let negated = self.builder.createFSub(zero, operand_value)
                  (operand_type, negated)
                }
                _ =>
                  raise CodeGenError::UnSupportFeature(
                    "Unary minus not supported for type \{operand_type}",
                  )
              }
            BitwiseNot =>
              // Bitwise NOT: XOR with all 1s
              match operand_type {
                Int(width) | UInt(width) => {
                  let all_ones = match width {
                    1 => self.global_ctx.llvm_ctx.getConstTrue()
                    8 => self.global_ctx.llvm_ctx.getConstInt8(-1)
                    16 => self.global_ctx.llvm_ctx.getConstInt16(-1)
                    32 => self.global_ctx.llvm_ctx.getConstInt32(-1)
                    64 => self.global_ctx.llvm_ctx.getConstInt64(-1L)
                    _ => self.global_ctx.llvm_ctx.getConstInt32(-1) // Fallback
                  }
                  let result = self.builder.createXor(operand_value, all_ones)
                  (operand_type, result)
                }
                _ =>
                  raise CodeGenError::UnSupportFeature(
                    "Bitwise NOT not supported for type \{operand_type}",
                  )
              }
            LogicalNot => {
              // Logical NOT: compare with zero
              let zero = match operand_type {
                Int(_) | UInt(_) =>
                  self.global_ctx.llvm_ctx.getConstInt32(0) as &LLVMValue
                FP(_) =>
                  self.global_ctx.llvm_ctx.getConstDouble(0.0) as &LLVMValue
                Ptr(_) =>
                  self.global_ctx.llvm_ctx.getConstInt32(0) as &LLVMValue // Null pointer
                _ => self.global_ctx.llvm_ctx.getConstInt32(0) as &LLVMValue // Fallback
              }
              let is_zero = self.builder.createICmpEQ(operand_value, zero)
              (Int(1), is_zero)
            }
          }
        }
      }
    SizeofTypeName(type_name) => {
      // Sizeof type: get size of specified type
      let expr_type = self.global_ctx.analysis_typename(type_name)
      let size_bytes = match expr_type {
        Int(1) | UInt(1) => 1
        Int(8) | UInt(8) => 1
        Int(16) | UInt(16) => 2
        Int(32) | UInt(32) => 4
        Int(64) | UInt(64) => 8
        FP(32) => 4
        FP(64) => 8
        Ptr(_) => 8 // Assume 64-bit pointers
        _ => 4 // Default size
      }
      let size_value = self.global_ctx.llvm_ctx.getConstInt32(size_bytes)
      (Int(32), size_value)
    }
    AlignOfTypeName(type_name) => {
      // AlignOf type: return alignment in bytes as compile-time constant
      let expr_type = self.global_ctx.analysis_typename(type_name)
      let align_bytes = match expr_type {
        Int(1) | UInt(1) => 1
        Int(8) | UInt(8) => 1
        Int(16) | UInt(16) => 2
        Int(32) | UInt(32) => 4
        Int(64) | UInt(64) => 8
        FP(32) => 4
        FP(64) => 8
        Ptr(_) => 8 // Assume 64-bit pointers
        _ => 4 // Default alignment
      }
      let align_value = self.global_ctx.llvm_ctx.getConstInt32(align_bytes)
      (Int(32), align_value)
    }
  }
}

///|
fn FuncCodeGenContext::emit_postfix_expr(
  self : Self,
  post_expr : PostFixExpr,
) -> (Type, &LLVMValue) raise {
  // Check if we have postfix increment/decrement operators
  let has_increment_decrement = post_expr.suffixes
    .iter()
    .any(fn(suffix) {
      match suffix {
        PlusPlus | MinusMinus => true
        _ => false
      }
    })

  // Check if we have function calls
  let has_function_call = post_expr.suffixes
    .iter()
    .any(fn(suffix) {
      match suffix {
        Call(_) => true
        _ => false
      }
    })

  // Evaluate the head of the postfix expression
  let (expr_type_init, expr_value_init) = match post_expr.head {
    Left(prim_expr) =>
      if has_increment_decrement {
        // For ++/-- operators, we need the lvalue (address) of the head
        self.emit_prim_expr_as_lvalue(prim_expr)
      } else if has_function_call {
        // For function calls, don't evaluate the head as an rvalue yet
        // We'll handle it in the Call suffix processing
        // Return dummy values for now
        (Int(32), self.global_ctx.llvm_ctx.getConstInt32(0))
      } else {
        // For other operators, evaluate normally as rvalue
        self.emit_prim_expr(prim_expr)
      }
    Right((type_name, init_list)) =>
      raise CodeGenError::UnSupportFeature(
        "Compound literals not supported yet",
      )
  }
  let mut expr_type = expr_type_init
  let mut expr_value = expr_value_init

  // Apply postfix operators in order (left to right)
  for suffix in post_expr.suffixes {
    match suffix {
      Indexing(index_expr) => {
        // Array indexing: base[index]
        let (index_type, index_value) = self.emit_expr(index_expr)
        match expr_type {
          Ptr(pointed_type) => {
            // For pointer arithmetic: ptr + index
            let elem_llvm_type = self.global_ctx.convert_type_to_llvm(
              pointed_type,
            )
            let gep = self.builder.createGEP(expr_value, elem_llvm_type, [
              index_value,
            ])
            let loaded_value = self.builder.createLoad(elem_llvm_type, gep)
            expr_type = pointed_type
            expr_value = loaded_value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Array indexing not supported for type \{expr_type}",
            )
        }
      }
      Call(arg_exprs) => {
        // Function call: func(args)
        // The expr_value should contain the function to call
        // First, we need to determine if this is a function name

        // For function calls, we need to get the function name from the head
        let func_name = match post_expr.head {
          Left(PrimExpr::Identifier(name)) => name
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Only direct function calls by name are supported",
            )
        }

        // Look up the function in the global function environment
        let func : @IR.Function = match
          self.global_ctx.function_env.get(func_name) {
          Some(f) => f
          None =>
            raise CodeGenError::UnSupportFeature(
              "Undefined function: \{func_name}",
            )
        }

        // Get function signature for type checking
        let (func_ret_type, func_params) = match
          self.global_ctx.function_sig_env.get(func_name) {
          Some(sig) => sig
          None =>
            raise CodeGenError::UnSupportFeature(
              "Function signature not found: \{func_name}",
            )
        }

        // Evaluate arguments and convert to match parameter types
        let arg_values : Array[&LLVMValue] = []
        for i, arg_expr in arg_exprs.iter2() {
          let (arg_type, arg_value) = self.emit_assign_expr(arg_expr)

          // Convert argument type to match expected parameter type if needed
          let converted_value = if i < func_params.length() {
            let (_, expected_param_type) = func_params[i]
            if arg_type != expected_param_type {
              self.emit_cast(
                from_type=arg_type,
                to_type=expected_param_type,
                arg_value,
              )
            } else {
              arg_value
            }
          } else {
            // For variadic functions or incorrect call, use as-is
            arg_value
          }
          arg_values.push(converted_value)
        }

        // Create the function call
        let call_result = self.builder.createCall(func, arg_values)

        // Use the actual return type from function signature
        expr_value = call_result
        expr_type = func_ret_type
      }
      DotAccess(field_name) =>
        raise CodeGenError::UnSupportFeature(
          "Struct field access not implemented",
        )
      ArrowAccess(field_name) =>
        raise CodeGenError::UnSupportFeature(
          "Pointer field access not implemented",
        )
      PlusPlus =>
        // Post-increment: return old value, increment stored value
        match expr_type {
          Int(_) | UInt(_) => {
            // expr_value is an address for post-increment (from lvalue evaluation)
            let llvm_type = self.global_ctx.convert_type_to_llvm(expr_type)
            let old_val = self.builder.createLoad(llvm_type, expr_value)
            let one = self.global_ctx.llvm_ctx.getConstInt32(1)
            let new_val = self.builder.createAdd(old_val, one)
            ignore(self.builder.createStore(new_val, expr_value))
            expr_value = old_val // Return old value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Post-increment not supported for type \{expr_type}",
            )
        }
      MinusMinus =>
        // Post-decrement: return old value, decrement stored value
        match expr_type {
          Int(_) | UInt(_) => {
            let llvm_type = self.global_ctx.convert_type_to_llvm(expr_type)
            let old_val = self.builder.createLoad(llvm_type, expr_value)
            let one = self.global_ctx.llvm_ctx.getConstInt32(1)
            let new_val = self.builder.createSub(old_val, one)
            ignore(self.builder.createStore(new_val, expr_value))
            expr_value = old_val // Return old value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Post-decrement not supported for type \{expr_type}",
            )
        }
    }
  }
  (expr_type, expr_value)
}

///|
fn FuncCodeGenContext::emit_prim_expr(
  self : Self,
  prim_expr : PrimExpr,
) -> (Type, &LLVMValue) raise {
  match prim_expr {
    Identifier(name) =>
      // Look up variable in environment
      match self.var_env.get(name) {
        Some((ty, alloca_value, is_array)) =>
          if is_array {
            // For array variables, return the address directly (decay to pointer)
            (ty, alloca_value)
          } else {
            // For normal variables (including pointer variables), load the value
            let llvm_type = self.global_ctx.convert_type_to_llvm(ty)
            let loaded_value = self.builder.createLoad(llvm_type, alloca_value)
            (ty, loaded_value)
          }
        None =>
          raise CodeGenError::UnSupportFeature("Undefined variable: \{name}")
      }
    Constant(constant) =>
      match constant {
        Int(value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstInt32(value)
          (Int(32), llvm_value)
        }
        Long(value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstInt64(value)
          (Int(64), llvm_value)
        }
        UInt(value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstInt32(
            value.reinterpret_as_int(),
          )
          (UInt(32), llvm_value)
        }
        ULong(value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstInt64(
            value.reinterpret_as_int64(),
          )
          (UInt(64), llvm_value)
        }
        Float(value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstFloat(value)
          (FP(32), llvm_value)
        }
        Double(value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstDouble(value)
          (FP(64), llvm_value)
        }
        Char(char_value) => {
          let llvm_value = self.global_ctx.llvm_ctx.getConstInt8(
            char_value.to_int(),
          )
          (Int(8), llvm_value)
        }
      }
    StringLiteral(str_value) =>
      raise CodeGenError::UnSupportFeature(
        "String literals not implemented yet",
      )
    ParenExpr(expr) =>
      // Parenthesized expression - just evaluate the inner expression
      self.emit_expr(expr)
    BuiltinOffsetof(type_name, unary_expr) =>
      raise CodeGenError::UnSupportFeature(
        "Builtin offsetof not implemented yet",
      )
  }
}

///|
fn FuncCodeGenContext::emit_unary_expr_as_lvalue(
  self : Self,
  unary_expr : UnaryExpr,
) -> (Type, &LLVMValue) raise {
  // For lvalue, we need to handle only the body of the unary expression
  // since prefix operators modify the value, not the address
  match unary_expr.body {
    PostFix(postfix_expr) => self.emit_postfix_expr_as_lvalue(postfix_expr)
    UnaryOp(op, cast_expr) =>
      match op {
        Dereference => {
          // *ptr - the result of dereferencing is an lvalue (address)
          let (operand_type, operand_value) = self.emit_cast_expr(cast_expr)
          match operand_type {
            Ptr(pointed_type) => (pointed_type, operand_value)
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Cannot dereference non-pointer type \{operand_type}",
              )
          }
        }
        _ =>
          raise CodeGenError::UnSupportFeature(
            "Unary operator \{op} does not produce an lvalue",
          )
      }
    SizeofTypeName(_) | AlignOfTypeName(_) =>
      raise CodeGenError::UnSupportFeature(
        "sizeof/alignof do not produce lvalues",
      )
  }
}

///|
fn FuncCodeGenContext::emit_postfix_expr_as_lvalue(
  self : Self,
  post_expr : PostFixExpr,
) -> (Type, &LLVMValue) raise {
  // Start with the head of the postfix expression
  let (expr_type_init, expr_value_init) = match post_expr.head {
    Left(prim_expr) => self.emit_prim_expr_as_lvalue(prim_expr)
    Right((type_name, init_list)) =>
      raise CodeGenError::UnSupportFeature(
        "Compound literals as lvalues not supported",
      )
  }
  let mut expr_type = expr_type_init
  let mut expr_value = expr_value_init

  // Apply postfix operators in order (left to right)
  for suffix in post_expr.suffixes {
    match suffix {
      Indexing(index_expr) => {
        // Array indexing: base[index] for lvalue (address calculation)
        let (index_type, index_value) = self.emit_expr(index_expr)
        match expr_type {
          Ptr(pointed_type) => {
            // For lvalue indexing: return the address (ptr + index)
            let elem_llvm_type = self.global_ctx.convert_type_to_llvm(
              pointed_type,
            )
            let gep = self.builder.createGEP(expr_value, elem_llvm_type, [
              index_value,
            ])
            expr_type = pointed_type
            expr_value = gep // Return address, not loaded value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Array indexing not supported for type \{expr_type}",
            )
        }
      }
      DotAccess(field_name) =>
        raise CodeGenError::UnSupportFeature(
          "Struct field access not implemented",
        )
      ArrowAccess(field_name) =>
        raise CodeGenError::UnSupportFeature(
          "Pointer field access not implemented",
        )
      Call(_) =>
        raise CodeGenError::UnSupportFeature(
          "Function calls do not produce lvalues",
        )
      PlusPlus | MinusMinus =>
        raise CodeGenError::UnSupportFeature(
          "Postfix increment/decrement do not produce lvalues",
        )
    }
  }
  (expr_type, expr_value)
}

///|
fn FuncCodeGenContext::emit_prim_expr_as_lvalue(
  self : Self,
  prim_expr : PrimExpr,
) -> (Type, &LLVMValue) raise {
  match prim_expr {
    Identifier(name) =>
      // Look up variable in environment and return its address (alloca)
      match self.var_env.get(name) {
        Some((ty, alloca_value, is_array)) => (ty, alloca_value) // Return address, not loaded value
        None =>
          raise CodeGenError::UnSupportFeature("Undefined variable: \{name}")
      }
    ParenExpr(expr) =>
      // Parenthesized expression - evaluate as lvalue
      // This requires implementing lvalue version of expr emission
      raise CodeGenError::UnSupportFeature(
        "Parenthesized lvalues not implemented",
      )
    Constant(_) | StringLiteral(_) | BuiltinOffsetof(_, _) =>
      raise CodeGenError::UnSupportFeature(
        "Constants and literals are not lvalues",
      )
  }
}

///|
fn FuncCodeGenContext::emit_iteration_statement(
  self : Self,
  iter_stmt : IterationStatement,
) -> Unit raise {
  match iter_stmt {
    While(cond, stmt) => self.emit_while(cond, stmt)
    DoWhile(stmt, cond_expr) => self.emit_do_while(stmt, cond_expr)
    For(for_cond, stmt) => self.emit_for(for_cond, stmt)
  }
}

///|
fn FuncCodeGenContext::emit_while(
  self : Self,
  cond : Expr,
  stmt : Statement,
) -> Unit raise {
  // Create basic blocks for the while loop
  let cond_bb = self.func_value.addBasicBlock(name="while.cond")
  let body_bb = self.func_value.addBasicBlock(name="while.body")
  let exit_bb = self.func_value.addBasicBlock(name="while.exit")

  // Jump to condition block
  ignore(self.builder.createBr(cond_bb))

  // Emit condition block
  self.builder.setInsertPoint(cond_bb)
  let (cond_type, cond_val) = self.emit_expr(cond)

  // Convert condition to boolean if needed
  let bool_cond = if cond_type != Int(1) && cond_type != UInt(1) {
    let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
    self.builder.createICmpNE(cond_val, zero)
  } else {
    cond_val
  }

  // Create conditional branch
  ignore(self.builder.createCondBr(bool_cond, body_bb, exit_bb))

  // Emit body block
  self.builder.setInsertPoint(body_bb)
  self.emit_statement(stmt)

  // Jump back to condition (if no explicit jump was made)
  ignore(self.builder.createBr(cond_bb))

  // Continue with exit block
  self.builder.setInsertPoint(exit_bb)
}

///|
fn FuncCodeGenContext::emit_do_while(
  self : Self,
  stmt : Statement,
  cond_expr : Expr,
) -> Unit raise {
  // For now, implement do-while as a simple while loop
  // TODO: Implement proper do-while semantics
  self.emit_while(cond_expr, stmt)
}

///|
fn FuncCodeGenContext::emit_for(
  self : Self,
  for_cond : ForCondition,
  stmt : Statement,
) -> Unit raise {
  let { for_init, cond, inc } = for_cond

  // Handle initialization
  match for_init {
    Declaration(decl) => self.emit_declaration(decl)
    InitExpr(expr) => ignore(self.emit_expr(expr))
    Empty => ()
  }

  // Create basic blocks for the for loop
  let cond_bb = self.func_value.addBasicBlock(name="for.cond")
  let body_bb = self.func_value.addBasicBlock(name="for.body")
  let inc_bb = self.func_value.addBasicBlock(name="for.inc")
  let exit_bb = self.func_value.addBasicBlock(name="for.exit")

  // Jump to condition block
  ignore(self.builder.createBr(cond_bb))

  // Emit condition block
  self.builder.setInsertPoint(cond_bb)
  if cond.length() > 0 {
    let cond_expr = Expr::{ exprs: cond }
    let (cond_type, cond_val) = self.emit_expr(cond_expr)

    // Convert condition to boolean if needed
    let bool_cond = if cond_type != Int(1) && cond_type != UInt(1) {
      let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
      self.builder.createICmpNE(cond_val, zero)
    } else {
      cond_val
    }

    // Create conditional branch
    ignore(self.builder.createCondBr(bool_cond, body_bb, exit_bb))
  } else {
    // No condition, always jump to body (infinite loop)
    ignore(self.builder.createBr(body_bb))
  }

  // Emit body block
  self.builder.setInsertPoint(body_bb)
  self.emit_statement(stmt)

  // Jump to increment block (if no explicit jump was made)
  ignore(self.builder.createBr(inc_bb))

  // Emit increment block
  self.builder.setInsertPoint(inc_bb)
  if inc.length() > 0 {
    let inc_expr = Expr::{ exprs: inc }
    ignore(self.emit_expr(inc_expr))
  }

  // Jump back to condition
  ignore(self.builder.createBr(cond_bb))

  // Continue with exit block
  self.builder.setInsertPoint(exit_bb)
}

///|
fn FuncCodeGenContext::emit_jump_statement(
  self : Self,
  jump_stmt : JumpStatement,
) -> Unit raise {
  match jump_stmt {
    Return(expr_opt) =>
      match expr_opt {
        Some(expr) => {
          let (expr_type, expr_val) = self.emit_expr(expr)
          // Convert the expression type to match the function's return type
          let return_val = if expr_type != self.return_type {
            self.emit_cast(
              from_type=expr_type,
              to_type=self.return_type,
              expr_val,
            )
          } else {
            expr_val
          }
          ignore(self.builder.createRet(return_val))
        }
        None => ignore(self.builder.createRetVoid())
      }
    _ =>
      // For now, skip other jump statements
      ()
  }
}

///|
fn FuncCodeGenContext::emit_selection_statement(
  self : Self,
  sel_stmt : SelectionStatement,
) -> Unit raise {
  match sel_stmt {
    If(cond_expr, then_stmt, else_stmt_opt) => {
      let (cond_type, cond_val) = self.emit_expr(cond_expr)

      // Convert condition to boolean if needed
      let bool_cond = if cond_type != Int(1) {
        let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
        self.builder.createICmpNE(cond_val, zero)
      } else {
        cond_val
      }
      let then_bb = self.func_value.addBasicBlock(name="then")
      let else_bb = self.func_value.addBasicBlock(name="else")
      let merge_bb = self.func_value.addBasicBlock(name="merge")

      // Create conditional branch
      ignore(self.builder.createCondBr(bool_cond, then_bb, else_bb))

      // Emit then block
      self.builder.setInsertPoint(then_bb)
      self.emit_statement(then_stmt)
      // Always add a branch to merge block for now
      ignore(self.builder.createBr(merge_bb))

      // Emit else block
      self.builder.setInsertPoint(else_bb)
      match else_stmt_opt {
        Some(else_stmt) => self.emit_statement(else_stmt)
        None => ()
      }
      // Always add a branch to merge block for now
      ignore(self.builder.createBr(merge_bb))

      // Continue with merge block
      self.builder.setInsertPoint(merge_bb)
    }
    Switch(_, _) =>
      // For now, skip switch statements
      ()
  }
}

///|
fn FuncCodeGenContext::analysis_declarator_type(
  self : Self,
  declarator : Declarator,
  base_type : Type,
) -> Type raise CodeGenError {
  let mut result_type = base_type

  // Handle pointer in declarator
  match declarator.pointer {
    Some(_) => result_type = Ptr(result_type)
    None => ()
  }

  // Handle direct declarator (arrays, functions, etc.)
  result_type = self.analysis_direct_declarator_type(
    declarator.directDeclarator,
    result_type,
  )
  result_type
}

///|

///|
fn FuncCodeGenContext::evaluate_constant_expr(
  self : Self,
  assign_expr : AssignExpr,
) -> Int raise CodeGenError {
  // Simple constant expression evaluator for array sizes
  match assign_expr {
    Conditional(cond_expr) => self.evaluate_constant_conditional(cond_expr)
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only simple constant expressions supported for array sizes",
      )
  }
}

///|
fn FuncCodeGenContext::evaluate_constant_conditional(
  self : Self,
  cond_expr : ConditionalExpr,
) -> Int raise CodeGenError {
  let { expr, select } = cond_expr
  if select is Some(_) {
    raise CodeGenError::UnSupportFeature(
      "Conditional expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_logical_or(expr)
}

///|
fn FuncCodeGenContext::evaluate_constant_logical_or(
  self : Self,
  log_or_expr : LogicalOrExpr,
) -> Int raise CodeGenError {
  let { exprs } = log_or_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex logical expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_logical_and(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_logical_and(
  self : Self,
  log_and_expr : LogicalAndExpr,
) -> Int raise CodeGenError {
  let { exprs } = log_and_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex logical expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_inclusive_or(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_inclusive_or(
  self : Self,
  incl_or_expr : InclusiveOrExpr,
) -> Int raise CodeGenError {
  let { exprs } = incl_or_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex bitwise expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_exclusive_or(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_exclusive_or(
  self : Self,
  excl_or_expr : ExclusiveOrExpr,
) -> Int raise CodeGenError {
  let { exprs } = excl_or_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex bitwise expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_and(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_and(
  self : Self,
  and_expr : AndExpr,
) -> Int raise CodeGenError {
  let { exprs } = and_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex bitwise expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_equality(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_equality(
  self : Self,
  eq_expr : EqualityExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = eq_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex equality expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_relational(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_relational(
  self : Self,
  rel_expr : RelationalExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = rel_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex relational expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_shift(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_shift(
  self : Self,
  shift_expr : ShiftExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = shift_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex shift expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_addsub(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_addsub(
  self : Self,
  add_expr : AddSubExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = add_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex arithmetic expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_mult(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_mult(
  self : Self,
  mult_expr : MultExpr,
) -> Int raise CodeGenError {
  let { exprs, ops } = mult_expr
  if exprs.length() != 1 {
    raise CodeGenError::UnSupportFeature(
      "Complex multiplication expressions not supported in array sizes",
    )
  }
  self.evaluate_constant_cast(exprs[0])
}

///|
fn FuncCodeGenContext::evaluate_constant_cast(
  self : Self,
  cast_expr : CastExpr,
) -> Int raise CodeGenError {
  match cast_expr {
    UnaryExpr(unary_expr) => self.evaluate_constant_unary(unary_expr)
    Cast(_, _) =>
      raise CodeGenError::UnSupportFeature(
        "Cast expressions not supported in array sizes",
      )
  }
}

///|
fn FuncCodeGenContext::evaluate_constant_unary(
  self : Self,
  unary_expr : UnaryExpr,
) -> Int raise CodeGenError {
  if !unary_expr.prefix.is_empty() {
    raise CodeGenError::UnSupportFeature(
      "Unary prefix operators not supported in array sizes",
    )
  }
  self.evaluate_constant_unary_body(unary_expr.body)
}

///|
fn FuncCodeGenContext::evaluate_constant_unary_body(
  self : Self,
  unary_body : UnaryExprBody,
) -> Int raise CodeGenError {
  match unary_body {
    PostFix(postfix_expr) => self.evaluate_constant_postfix(postfix_expr)
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only simple postfix expressions supported in array sizes",
      )
  }
}

///|
fn FuncCodeGenContext::evaluate_constant_postfix(
  self : Self,
  post_expr : PostFixExpr,
) -> Int raise CodeGenError {
  if !post_expr.suffixes.is_empty() {
    raise CodeGenError::UnSupportFeature(
      "Postfix operators not supported in array sizes",
    )
  }
  match post_expr.head {
    Left(prim_expr) => self.evaluate_constant_primary(prim_expr)
    Right(_) =>
      raise CodeGenError::UnSupportFeature(
        "Compound literals not supported in array sizes",
      )
  }
}

///|
fn FuncCodeGenContext::evaluate_constant_primary(
  self : Self,
  prim_expr : PrimExpr,
) -> Int raise CodeGenError {
  match prim_expr {
    Constant(constant) =>
      match constant {
        Int(value) => value
        Long(value) => value.to_int()
        UInt(value) => value.reinterpret_as_int()
        ULong(value) => value.reinterpret_as_int64().to_int()
        _ =>
          raise CodeGenError::UnSupportFeature(
            "Only integer constants supported in array sizes",
          )
      }
    ParenExpr(expr) => {
      if expr.exprs.length() != 1 {
        raise CodeGenError::UnSupportFeature(
          "Complex parenthesized expressions not supported in array sizes",
        )
      }
      self.evaluate_constant_expr(expr.exprs[0])
    }
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only integer constants supported in array sizes",
      )
  }
}

///|
fn FuncCodeGenContext::analysis_direct_declarator_type(
  self : Self,
  direct_declarator : DirectDeclarator,
  base_type : Type,
) -> Type raise CodeGenError {
  match direct_declarator {
    Identifier(_) => base_type
    Array(inner_declarator, _type_quals, size_expr) => {
      // Handle array declarator: int arr[5]
      let element_type = self.analysis_direct_declarator_type(
        inner_declarator, base_type,
      )
      let array_size = match size_expr {
        Some(assign_expr) =>
          // Evaluate constant array size expression
          self.evaluate_constant_expr(assign_expr)
        None =>
          raise CodeGenError::UnSupportFeature(
            "Variable length arrays are not supported",
          )
      }
      Array(element_type, array_size)
    }
    StaticArray(inner_declarator, _type_quals, _size_expr) => {
      // Handle static array declarator
      let element_type = self.analysis_direct_declarator_type(
        inner_declarator, base_type,
      )
      // TODO: Implement proper static array handling
      Array(element_type, 1) // Placeholder
    }
    Parenthesized(inner_declarator) =>
      // Handle parenthesized declarator
      self.analysis_declarator_type(inner_declarator, base_type)
    _ =>
      raise CodeGenError::UnSupportFeature("Unsupported direct declarator type")
  }
}

///|
fn FuncCodeGenContext::emit_declaration(
  self : Self,
  decl : Declaration,
) -> Unit raise {
  match decl {
    Decl(declspecs, inits) => self.emit_decl(declspecs, inits)
  }
}

///|
fn FuncCodeGenContext::emit_decl(
  self : Self,
  declspecs : Array[DeclSpec],
  inits : Array[InitDeclarator],
) -> Unit raise {
  // Get the base type from declaration specifiers
  let base_type = self.global_ctx.analysis_declspecs(declspecs)

  // Process each declarator with initializer
  for init_decl in inits {
    let { declarator, initializer } = init_decl
    let var_name = declarator.get_ident()

    // Analyze the declarator to get the final type
    let var_type = self.analysis_declarator_type(declarator, base_type)

    // Allocate space for the variable
    let (llvm_type, env_type, alloca, is_array) = match var_type {
      Array(elem_type, size) => {
        // For array variables, allocate the array and store the pointer type in environment
        let array_llvm_type = self.global_ctx.convert_type_to_llvm(var_type)
        let array_alloca = self.builder.createAlloca(
          array_llvm_type,
          name=var_name,
        )

        // Array variable name refers to a pointer to the first element
        let ptr_type = Ptr(elem_type)
        (array_llvm_type, ptr_type, array_alloca, true)
      }
      _ => {
        let llvm_type = self.global_ctx.convert_type_to_llvm(var_type)
        let alloca = self.builder.createAlloca(llvm_type, name=var_name)
        (llvm_type, var_type, alloca, false)
      }
    }

    // Store the variable in the environment
    self.var_env.set(var_name, (env_type, alloca, is_array))

    // Handle initialization if present
    match initializer {
      Some(init) =>
        // For now, only handle simple expression initializers
        match init {
          AssignExpr(assign_expr) => {
            let (init_type, init_val) = self.emit_assign_expr(assign_expr)
            let init_val = if init_type != var_type {
              self.emit_cast(from_type=init_type, to_type=var_type, init_val)
            } else {
              init_val
            }
            ignore(self.builder.createStore(init_val, alloca))
          }
          InitList(init_pairs) =>
            // Handle array initialization lists like {1, 2, 3, 4, 5}
            match var_type {
              Array(elem_type, size) => {
                // Initialize array elements one by one
                let elem_llvm_type = self.global_ctx.convert_type_to_llvm(
                  elem_type,
                )
                let mut index = 0
                for pair in init_pairs {
                  let (designators, initializer) = pair
                  // For simple array initialization, ignore designators for now
                  if index >= size {
                    break // Don't initialize beyond array bounds
                  }

                  // Get the value to initialize with
                  let init_val = match initializer {
                    AssignExpr(assign_expr) => {
                      let (init_type, init_val) = self.emit_assign_expr(
                        assign_expr,
                      )
                      if init_type != elem_type {
                        self.emit_cast(
                          from_type=init_type,
                          to_type=elem_type,
                          init_val,
                        )
                      } else {
                        init_val
                      }
                    }
                    InitList(_) =>
                      raise CodeGenError::UnSupportFeature(
                        "Nested InitList not supported yet",
                      )
                  }

                  // Calculate the GEP to the array element
                  let index_val = self.global_ctx.llvm_ctx.getConstInt32(index)
                  let array_llvm_type = self.global_ctx.convert_type_to_llvm(
                    var_type,
                  )
                  let gep = self.builder.createGEP(alloca, array_llvm_type, [
                    self.global_ctx.llvm_ctx.getConstInt32(0), // First index for array base
                    index_val, // Second index for array element
                  ])

                  // Store the value
                  ignore(self.builder.createStore(init_val, gep))
                  index = index + 1
                }
              }
              _ =>
                raise CodeGenError::UnSupportFeature(
                  "InitList only supported for array types currently",
                )
            }
        }
      None =>
        // No initialization - variable is uninitialized
        ()
    }
  }
}
