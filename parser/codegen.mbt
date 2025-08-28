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
  Struct(Array[Type])
  Union(Array[Type])
  Enum(Array[(String, Int64)])
} derive(Show, Eq)

///|
fn CodeGenContext::convert_type_to_llvm(self : Self, ty : Type) -> &LLVMType {
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
    Struct(_) => ...
    Union(_) => ...
    Enum(_) => ...
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
  CodeGenContext::{
    external_decls: ctx.external_decls,
    llvm_ctx,
    llvm_mod,
    function_env,
  }
}

///|
pub fn CodeGenContext::analysis_declspecs(
  self : Self,
  declspecs : Array[DeclSpec],
) -> Type {
  let mut is_signed = true
  let mut base_type : Type? = None
  let mut is_long = false
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
          Long => is_long = true
          Float => base_type = Some(FP(32))
          Double => base_type = Some(FP(64))
          Signed => is_signed = true
          Unsigned => {
            is_signed = false
            is_unsigned = true
          }
          Bool => base_type = Some(Int(1))
          Complex => ...
          Atomic(_) => ...
          StructSpec(_) => ...
          UnionSpec(_) => ...
          EnumSpec(_) => base_type = Some(Enum([]))
          TypedefName(_) => ...
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
          let final_width = if is_long {
            64
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
      if is_long {
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
    FuncDecl(inner_opt, _param_type_list) => ...
    ArrayDecl(inner_opt, is_static~, _type_quals, _size_expr) => ...
    InCompleteArray(inner_opt) => ...
    FuncPtr(inner_opt, _abstract_decl) => ...
  }
}

///|
pub fn CodeGenContext::emit_declaration(
  self : Self,
  decl : Declaration,
) -> Unit {
  ...
}

///|
struct FuncCodeGenContext {
  global_ctx : CodeGenContext
  func_def : FunctionDefinition
  func_value : @IR.Function
  var_env : Env[(Type, &LLVMValue)]
  builder : @IR.IRBuilder
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
  let var_env : Env[(Type, &LLVMValue)] = Env::new()
  for i in 0..<params.length() {
    let (param_name, param_type) = params[i]
    let llvm_param = llvm_func.getArg(i).unwrap()
    var_env.set(param_name, (param_type, llvm_param))
  }
  let builder = self.llvm_ctx.createBuilder()
  let func_codegen = FuncCodeGenContext::{
    global_ctx: self,
    func_def,
    func_value: llvm_func,
    var_env,
    builder,
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
      for param in params {
        let { decl_specs, declarator } = param
        guard declarator is Some(declarator) else {
          raise CodeGenError::UnSupportFeature(
            "Parameter without declarator is not supported.",
          )
        }
        guard declarator is Declarator(declarator) else {
          raise CodeGenError::UnSupportFeature(
            "Only simple parameter declarators are supported.",
          )
        }
        let param_type = self.analysis_declspecs(decl_specs)
        let (param_type, param_name) = self.analysis_param_declarator(
          declarator, param_type,
        )
        func_params.push((param_name, param_type))
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
      for param in params {
        let { decl_specs, declarator } = param
        guard declarator is Some(declarator) else {
          raise CodeGenError::UnSupportFeature(
            "Parameter without declarator is not supported.",
          )
        }
        guard declarator is Declarator(declarator) else {
          raise CodeGenError::UnSupportFeature(
            "Only simple parameter declarators are supported.",
          )
        }
        let param_type = self.analysis_declspecs(decl_specs)
        let (param_type, param_name) = self.analysis_param_declarator(
          declarator, param_type,
        )
        func_params.push((param_name, param_type))
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
  let entry_bb = self.func_value.addBasicBlock(name="entry")
  self.builder.setInsertPoint(entry_bb)
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
    LabeledStatement(label) => ...
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

    // Integer extension/truncation
    (Int(from_width), Int(to_width)) =>
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

    // For other cases, use bitcast as fallback
    _ => {
      let to_llvm_type = self.global_ctx.convert_type_to_llvm(to_type)
      match to_llvm_type.tryAsPrimitiveType() {
        Some(prim_type) => self.builder.createBitCast(value, prim_type)
        None => value // If bitcast fails, return original value
      }
    }
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
  let (first_ty, first_val) = self.emit_exclusive_or_expr(exclusive_or_exprs[0])
  for i in 1..<exclusive_or_exprs.length() {
    let (ty, val) = self.emit_exclusive_or_expr(exclusive_or_exprs[i])
    let first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }

  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_exclusive_or_expr(
  self : Self,
  excl_or_expr : ExclusiveOrExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: and_exprs } = excl_or_expr
  let (first_ty, first_val) = self.emit_and_expr(and_exprs[0])
  for i in 1..<and_exprs.length() {
    let (ty, val) = self.emit_and_expr(and_exprs[i])
    let first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }

  }
  (first_ty, first_val)
}

///|
fn FuncCodeGenContext::emit_and_expr(
  self : Self,
  and_expr : AndExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: equality_exprs } = and_expr
  let (first_ty, first_val) = self.emit_equality_expr(equality_exprs[0])
  for i in 1..<equality_exprs.length() {
    let (ty, val) = self.emit_equality_expr(equality_exprs[i])
    let first_val = if first_ty != ty {
      self.emit_cast(from_type=first_ty, to_type=ty, first_val)
    } else {
      first_val
    }

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
      Shr => self.builder.createAShr(first_val, val)
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
    UnaryOp(op, cast_expr) => {
      let (operand_type, operand_value) = self.emit_cast_expr(cast_expr)
      match op {
        AddressOf => {
          // Address-of operator: get address of lvalue
          // We need to get the lvalue (address) of the operand
          let (lvalue_type, lvalue_addr) = self.emit_cast_expr_as_lvalue(
            cast_expr,
          )
          (Ptr(lvalue_type), lvalue_addr)
        }
        Dereference =>
          // Dereference operator: load from pointer
          match operand_type {
            Ptr(pointed_type) => {
              let llvm_type = self.global_ctx.convert_type_to_llvm(pointed_type)
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
            FP(_) => ...
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
            FP(_) => self.global_ctx.llvm_ctx.getConstDouble(0.0) as &LLVMValue
            Ptr(_) => self.global_ctx.llvm_ctx.getConstInt32(0) as &LLVMValue // Null pointer
            _ => self.global_ctx.llvm_ctx.getConstInt32(0) as &LLVMValue // Fallback
          }
          let is_zero = self.builder.createICmpEQ(operand_value, zero)
          (Int(1), is_zero)
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
        Ptr(_) => 8
        ...
      } // Assume 64-bit pointers
      // Default size
      let size_value = self.global_ctx.llvm_ctx.getConstInt32(size_bytes)
      (Int(32), size_value)
    }
    AlignOfTypeName(type_name) => ...
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
    Right((type_name, init_list)) => ...
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
          Ptr(_) => ...
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

        // Evaluate arguments
        let arg_values : Array[&LLVMValue] = []
        let arg_types : Array[Type] = []
        for arg_expr in arg_exprs {
          let (arg_type, arg_value) = self.emit_assign_expr(arg_expr)
          arg_values.push(arg_value)
          arg_types.push(arg_type)
        }

        // Create the function call
        let call_result = self.builder.createCall(func, arg_values)

        // Determine return type - for now assume int
        // TODO: Get actual return type from function signature
        expr_value = call_result
        expr_type = Int(32) // Assume int return type for now
      }
      DotAccess(_) => ...
      ArrowAccess(_) => ...
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
        Some((ty, alloca_value)) => {
          // Load the value from the alloca address
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
          let llvm_value = self.global_ctx.llvm_ctx.getConstFloat(
            value.to_double(),
          )
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
    StringLiteral(str_value) => ...
    ParenExpr(expr) =>
      // Parenthesized expression - just evaluate the inner expression
      self.emit_expr(expr)
    BuiltinOffsetof(type_name, unary_expr) => ...
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
  let expr_type = expr_type_init
  let expr_value = expr_value_init

  // Apply postfix operators in order (left to right)
  for suffix in post_expr.suffixes {
    match suffix {
      Indexing(index_expr) =>
        // Array indexing: base[index] - skip for now
        raise CodeGenError::UnSupportFeature(
          "Array indexing not implemented yet",
        )
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
        Some((ty, alloca_value)) => (ty, alloca_value) // Return address, not loaded value
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
    While(cond, stmt) => ...
    DoWhile(stmt, cond_expr) => ...
    For(for_cond, stmt) => ...
  }
}

///|
fn FuncCodeGenContext::emit_while(
  self : Self,
  cond : Expr,
  stmt : Statement,
) -> Unit raise {
  ...
}

///|
fn FuncCodeGenContext::emit_do_while(
  self : Self,
  stmt : Statement,
  cond_expr : Expr,
) -> Unit raise {
  ...
}

///|
fn FuncCodeGenContext::emit_for(
  self : Self,
  for_cond : ForCondition,
  stmt : Statement,
) -> Unit raise {
  ...
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
          ignore(self.builder.createRet(expr_val))
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

    // For now, we only support simple declarators (no pointers, arrays, etc.)
    let var_type = match declarator.pointer {
      Some(_) => Ptr(base_type)
      None => base_type
    }

    // Allocate space for the variable
    let llvm_type = self.global_ctx.convert_type_to_llvm(var_type)
    let alloca = self.builder.createAlloca(llvm_type, name=var_name)

    // Store the variable in the environment
    self.var_env.set(var_name, (var_type, alloca))

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
          InitList(_) =>
            // Skip complex initializer lists for now
            raise CodeGenError::UnSupportFeature(
              "InitList initializers not supported yet",
            )
        }
      None =>
        // No initialization - variable is uninitialized
        ()
    }
  }
}
