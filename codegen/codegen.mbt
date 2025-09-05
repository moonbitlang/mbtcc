// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


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
  Struct(String, Array[(String, Type)]) // name, (field_name, field_type)
  Union(Array[(String, Type)])
  Enum(Array[(String, Int64)])
} derive(Show, Eq)

///|
fn CodeGenContext::convert_type_to_llvm(
  self : Self,
  ty : Type,
) -> &LLVMType raise {
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
      self.llvm_ctx.getArrayType(element_llvm_type, size)
    }
    Struct(struct_name, field_types) => {
      let full_struct_name = "struct." + struct_name
      // Check if we already created this LLVM struct type
      match self.llvm_struct_env.get(full_struct_name) {
        Some(cached_llvm_type) => cached_llvm_type
        None => {
          // Convert each field type to LLVM type
          let llvm_field_types : Array[&LLVMType] = []
          for field_type in field_types {
            let (_, field_type) = field_type
            let llvm_field_type = self.convert_type_to_llvm(field_type)
            llvm_field_types.push(llvm_field_type)
          }
          // Create LLVM struct type using Context::getStructType with a name
          // Try both packed and unpacked to see what's happening
          let llvm_struct_type = self.llvm_ctx.getStructType(
            llvm_field_types,
            name=full_struct_name,
            isPacked=false, // Test: try unpacked
          )
          // Cache the LLVM struct type
          self.llvm_struct_env.set(full_struct_name, llvm_struct_type)
          llvm_struct_type
        }
      }
    }
    Union(_) =>
      raise CodeGenError::UnSupportFeature("Union types not implemented yet")
    Enum(_) =>
      raise CodeGenError::UnSupportFeature("Enum types not implemented yet")
  }
}

///|
pub suberror CodeGenError {
  SyntaxError(String)
  UnSupportFeature(String)
} derive(Show)

///|
struct CodeGenContext {
  external_decls : Array[ExternalDeclaration]
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  function_env : Env[@IR.Function] // Global function symbol table
  function_sig_env : Env[(Type, Array[(String, Type)])] // Function signature table: (return_type, parameters)
  global_var_env : Env[(@IR.GlobalVariable, Type)] // Global variable symbol table: (LLVM value, type)
  typedef_env : Env[Type] // Type alias symbol table
  struct_env : Env[Type] // Struct type cache
  llvm_struct_env : Env[&LLVMType] // LLVM struct type cache
  mut anon_struct_counter : Int // Counter for generating unique anonymous struct names
}

///|
pub fn CodeGenContext::dump(self : Self) -> Unit {
  println(self.llvm_mod)
}

///|
pub fn CodeGenContext::from_parser(ctx : ParserContext) -> CodeGenContext {
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule(ctx.source_file)
  let function_env = Env::new()
  let function_sig_env = Env::new()
  let global_var_env = Env::new()
  let typedef_env = Env::new()
  let struct_env = Env::new()
  let llvm_struct_env = Env::new()
  CodeGenContext::{
    external_decls: ctx.external_decls,
    llvm_ctx,
    llvm_mod,
    function_env,
    function_sig_env,
    global_var_env,
    typedef_env,
    struct_env,
    llvm_struct_env,
    anon_struct_counter: 0,
  }
}

///|
fn CodeGenContext::analysis_declarator_type_for_struct(
  self : Self,
  declarator : Declarator,
  base_type : Type,
) -> (String, Type) raise {
  let mut result_type = base_type

  // Handle pointer in declarator
  match declarator.pointer {
    Some(pointer) => {
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        result_type = Ptr(result_type)
      }
    }
    None => ()
  }

  // Handle direct declarator (arrays, functions, etc.)
  // For struct fields, we mainly care about arrays and pointers
  result_type = self.analysis_direct_declarator_type_for_struct(
    declarator.directDeclarator,
    result_type,
  )

  // Get identifier name from direct declarator
  let field_name = declarator.directDeclarator.get_ident()
  (field_name, result_type)
}

///|
fn CodeGenContext::analysis_direct_declarator_type_for_struct(
  self : Self,
  direct_declarator : DirectDeclarator,
  base_type : Type,
) -> Type raise {
  match direct_declarator {
    Identifier(_) => base_type
    Array(inner_declarator, _type_quals, size_expr) => {
      // Handle array declarator in struct field: int arr[5]
      let element_type = self.analysis_direct_declarator_type_for_struct(
        inner_declarator, base_type,
      )
      let array_size = match size_expr {
        Some(assign_expr) =>
          // Evaluate constant array size expression
          self.evaluate_constant_expr(assign_expr)
        None =>
          raise CodeGenError::UnSupportFeature(
            "Variable length arrays are not supported in struct fields",
          )
      }
      Array(element_type, array_size)
    }
    StaticArray(inner_declarator, _type_quals, size_expr) => {
      // Handle static array declarator
      let element_type = self.analysis_direct_declarator_type_for_struct(
        inner_declarator, base_type,
      )
      let array_size = self.evaluate_constant_expr(size_expr)
      Array(element_type, array_size)
    }
    Parenthesized(inner_decl) => {
      // For parenthesized declarators, analyze the full declarator
      let (_, field_type) = self.analysis_declarator_type_for_struct(
        inner_decl, base_type,
      )
      field_type
    }
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Unsupported declarator type in struct field: functions and complex declarators not supported",
      )
  }
}

///|
fn CodeGenContext::analysis_struct_spec(
  self : Self,
  struct_spec : StructSpec,
) -> Type raise {
  // Get struct name first
  let struct_name = match struct_spec.name {
    Some(name) => name
    None => {
      let name = "anon_\{self.anon_struct_counter}"
      self.anon_struct_counter = self.anon_struct_counter + 1
      name
    }
  }

  // Check if this struct is already defined (for forward references)
  match self.struct_env.get(struct_name) {
    Some(existing_struct_type) => existing_struct_type
    None => {
      // Create struct type from struct specification
      let fields : Array[(String, Type)] = []
      for struct_decl in struct_spec.decls {
        match struct_decl {
          Normal(spec_qualifiers, struct_declarators) => {
            // Convert spec_qualifiers to declspecs and use the standard analysis
            let declspecs : Array[DeclSpec] = []
            for spec in spec_qualifiers {
              match spec {
                TypeSpec(type_spec) =>
                  declspecs.push(DeclSpec::TypeSpec(type_spec))
                TypeQualifier(type_qual) =>
                  declspecs.push(DeclSpec::TypeQualifier(type_qual))
              }
            }

            // Get the base type using the standard analysis
            let field_base_type = self.analysis_declspecs(declspecs)

            // Process each field declarator
            for struct_declarator in struct_declarators {
              match struct_declarator {
                Declarator(declarator) => {
                  // Get the field type considering the declarator
                  let (field_name, field_type) = self.analysis_declarator_type_for_struct(
                    declarator, field_base_type,
                  )
                  fields.push((field_name, field_type))
                }
                _ =>
                  raise CodeGenError::UnSupportFeature(
                    "Only simple declarators are supported in struct fields.",
                  )
              }
            }
          }
        }
      }
      // Create and cache the struct type
      let struct_type = Type::Struct(struct_name, fields)
      if !struct_spec.decls.is_empty() {
        // Only cache if this is a complete definition
        self.struct_env.set(struct_name, struct_type)
      }
      struct_type
    }
  }
}

///|
pub fn CodeGenContext::analysis_declspecs(
  self : Self,
  declspecs : Array[DeclSpec],
) -> Type raise {
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
          StructSpec(struct_spec) =>
            base_type = Some(self.analysis_struct_spec(struct_spec))
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

///|
fn CodeGenContext::analysis_direct_declarator_type_for_param(
  self : Self,
  direct_declarator : DirectDeclarator,
  base_type : Type,
) -> Type raise CodeGenError {
  match direct_declarator {
    Identifier(_) => base_type
    Array(inner_declarator, _, size_expr) => {
      // Recursively analyze inner declarator first
      let inner_type = self.analysis_direct_declarator_type_for_param(
        inner_declarator, base_type,
      )
      // Get array size
      let array_size = match size_expr {
        Some(assign_expr) => self.evaluate_constant_expr(assign_expr)
        None => 0 // Unsized array
      }
      if array_size > 0 {
        Type::Array(inner_type, array_size)
      } else {
        inner_type // For unsized arrays, just use the inner type
      }
    }
    StaticArray(inner_declarator, _, size_expr) => {
      let inner_type = self.analysis_direct_declarator_type_for_param(
        inner_declarator, base_type,
      )
      let array_size = self.evaluate_constant_expr(size_expr)
      Type::Array(inner_type, array_size)
    }
    Parenthesized(inner_decl) => {
      // For parenthesized declarators, we need to handle the full declarator
      let (param_type, _) = self.analysis_param_declarator(
        inner_decl, base_type,
      )
      param_type
    }
    _ => base_type // For other cases, just return base type
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
    Some(pointer) => {
      // Handle multiple levels of pointers
      // Each element in pointer.inner() represents one level of pointer
      let mut result_type = basic_type
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        result_type = Ptr(result_type)
      }
      result_type
    }
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
    Array(inner_declarator, _, size_expr) => {
      // For array parameters like int a[3][3], only the FIRST dimension decays.
      // So int a[3][3] becomes int (*a)[3], not int (*a)[3][3].

      // The inner_declarator gives us the rest of the type
      // For a[3][3], inner_declarator is a[3]
      // For a[3], inner_declarator is a (identifier)

      // Recursively analyze to get the element type (what remains after first dimension)
      let element_type = self.analysis_direct_declarator_type_for_param(
        inner_declarator, param_type,
      )

      // Apply decay: the first array dimension decays to pointer
      // So we return Ptr(element_type), not Ptr(Array(element_type, size))
      Ptr(element_type)
    }
    StaticArray(inner_declarator, _, size_expr) => {
      // Similar to Array case
      let inner_type = self.analysis_direct_declarator_type_for_param(
        inner_declarator, param_type,
      )
      let array_size = self.evaluate_constant_expr(size_expr)
      let array_type = Type::Array(inner_type, array_size)
      Ptr(array_type)
    }
    VallengthArray(inner_declarator, _) => {
      // Variable length array - also treated as pointer
      let inner_type = self.analysis_direct_declarator_type_for_param(
        inner_declarator, param_type,
      )
      Ptr(inner_type)
    }
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
) -> Type raise {
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
    Some(pointer) => {
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        result_type = Ptr(result_type)
      }
    }
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
  ignore(self)
  ignore(base_type)
  match direct_abstract_decl {
    FuncDecl(_, _param_type_list) =>
      raise CodeGenError::UnSupportFeature(
        "Function declarations in abstract declarators not supported",
      )
    ArrayDecl(_) =>
      raise CodeGenError::UnSupportFeature(
        "Array declarations in abstract declarators not supported",
      )
    InCompleteArray(_) =>
      raise CodeGenError::UnSupportFeature(
        "Incomplete arrays in abstract declarators not supported",
      )
    FuncPtr(_) =>
      raise CodeGenError::UnSupportFeature(
        "Function pointers in abstract declarators not supported",
      )
  }
}

///|
fn CodeGenContext::analysis_global_declarator_type(
  self : Self,
  declarator : Declarator,
  base_type : Type,
) -> Type raise CodeGenError {
  let mut result_type = base_type

  // Handle pointer in declarator
  match declarator.pointer {
    Some(pointer) => {
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        result_type = Ptr(result_type)
      }
    }
    None => ()
  }

  // Handle direct declarator (arrays, functions, etc.)
  result_type = self.analysis_global_direct_declarator_type(
    declarator.directDeclarator,
    result_type,
  )
  result_type
}

///|
fn CodeGenContext::analysis_global_direct_declarator_type(
  self : Self,
  direct_declarator : DirectDeclarator,
  base_type : Type,
) -> Type raise CodeGenError {
  match direct_declarator {
    Identifier(_) => base_type
    Array(inner_declarator, _type_quals, size_expr) => {
      // Handle array declarator: int arr[5]
      let element_type = self.analysis_global_direct_declarator_type(
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
      let element_type = self.analysis_global_direct_declarator_type(
        inner_declarator, base_type,
      )
      // TODO: Implement proper static array handling
      Array(element_type, 1) // Placeholder
    }
    Parenthesized(inner_declarator) =>
      // Handle parenthesized declarator
      self.analysis_global_declarator_type(inner_declarator, base_type)
    _ =>
      raise CodeGenError::UnSupportFeature("Unsupported direct declarator type")
  }
}

///|
pub fn CodeGenContext::emit_declaration(
  self : Self,
  decl : Declaration,
) -> Unit raise {
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
            raise CodeGenError::SyntaxError(
              "Typedef declarations cannot have initializers",
            )
          }
          let typedef_name = declarator.get_ident()
          // Handle typedef with pointers
          let mut typedef_type = base_type
          match declarator.pointer {
            Some(pointer) => {
              let pointer_levels = pointer.inner()
              for _ in pointer_levels {
                typedef_type = Ptr(typedef_type)
              }
            }
            None => ()
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
              raise CodeGenError::SyntaxError(
                "Function declarations cannot have initializers",
              )
            }
            let (ret_type, func_name, params, isVarArg) = self.analysis_func_declarator(
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
              llvm_ret_type,
              param_types,
              isVarArg~,
            )

            // Declare the function (extern if not already defined)
            let llvm_func = self.llvm_mod.addFunction(func_type, func_name)

            // Add function to global function environment
            self.function_env.set(func_name, llvm_func)
            // Store function signature for type checking during calls
            self.function_sig_env.set(func_name, (ret_type, params))
          } else {
            // Handle global variable declaration
            let var_name = declarator.get_ident()

            // Analyze the declarator to get the final type
            let var_type = self.analysis_global_declarator_type(
              declarator, base_type,
            )

            // Convert to LLVM type
            let llvm_type = self.convert_type_to_llvm(var_type)

            // Create the global variable with zero initialization for now
            // TODO: Implement proper initializer handling later
            let global_var = match var_type {
              Array(element_type, array_size) =>
                // For arrays of integers, create zero-initialized array constant
                match element_type {
                  Int(_) => {
                    let element_llvm_type = self.convert_type_to_llvm(
                      element_type,
                    )
                    let zero_element = self.llvm_ctx.getConstInt32(0)
                    let zero_elements : Array[&@IR.Constant] = Array::make(
                      array_size, zero_element,
                    )
                    let zero_init = self.llvm_ctx.getConstArray(
                      element_llvm_type, zero_elements,
                    )
                    self.llvm_mod.addGlobalVariable(
                      llvm_type,
                      initializer=zero_init,
                      name=var_name,
                    )
                  }
                  Ptr(_) => {
                    // For arrays of pointers, create null-initialized array constant
                    let element_llvm_type = self.convert_type_to_llvm(
                      element_type,
                    )
                    let null_element = self.llvm_ctx.getConstPointerNull(
                      element_llvm_type,
                    )
                    let null_elements : Array[&@IR.Constant] = Array::make(
                      array_size, null_element,
                    )
                    let null_init = self.llvm_ctx.getConstArray(
                      element_llvm_type, null_elements,
                    )
                    self.llvm_mod.addGlobalVariable(
                      llvm_type,
                      initializer=null_init,
                      name=var_name,
                    )
                  }
                  _ =>
                    // For other element types, create without initializer for now
                    self.llvm_mod.addGlobalVariable(llvm_type, name=var_name)
                }
              Int(_) => {
                let zero_init = self.llvm_ctx.getConstInt32(0)
                self.llvm_mod.addGlobalVariable(
                  llvm_type,
                  initializer=zero_init,
                  name=var_name,
                )
              }
              _ =>
                // For other types, create without initializer for now
                self.llvm_mod.addGlobalVariable(llvm_type, name=var_name)
            }

            // Add to global variable environment
            self.global_var_env.set(var_name, (global_var, var_type))
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
  mut block_counter : Int // Counter for generating unique basic block names
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
  let (ret_type, func_name, params, isVarArg) = self.analysis_func_declarator(
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
  let func_type = self.llvm_ctx.getFunctionType(
    llvm_ret_type,
    param_types,
    isVarArg~,
  )
  let llvm_func = self.llvm_mod.addFunction(func_type, func_name)
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
    // For parameters, is_array should be false because they are already decayed
    // Array parameters have already been converted to pointers during analysis
    var_env.set(param_name, (param_type, alloca, false))
  }
  let func_codegen = FuncCodeGenContext::{
    global_ctx: self,
    func_def,
    func_value: llvm_func,
    var_env,
    builder,
    return_type: ret_type,
    block_counter: 0,
  }
  func_codegen.emit_function_body()
}

///|
fn CodeGenContext::analysis_func_declarator(
  self : Self,
  decl : Declarator,
  basic_type : Type,
) -> (Type, String, Array[(String, Type)], Bool) raise {
  let mut ret_type = basic_type
  match decl.pointer {
    Some(pointer) => {
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        ret_type = Ptr(ret_type)
      }
    }
    None => ()
  }
  let (func_name, params, variadic) = match decl.directDeclarator {
    FunctionDecl(Identifier(func_name), param_type_list) => {
      let func_params : Array[(String, Type)] = []
      let { params, variadic } = param_type_list
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
      (func_name, func_params, variadic)
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
      (func_name, func_params, false)
    }
    FunctionDecl(nested_decl, param_type_list) => {
      // Handle nested function declarators
      let func_name = nested_decl.get_ident()
      let func_params : Array[(String, Type)] = []
      let { params, variadic } = param_type_list
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
      (func_name, func_params, variadic)
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
      (func_name, func_params, false)
    }
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only function declarators are supported.",
      )
  }
  (ret_type, func_name, params, variadic)
}

///|
fn FuncCodeGenContext::calculate_type_size(self : Self, ty : Type) -> Int {
  match ty {
    Int(1) | UInt(1) => 1 // bool
    Int(8) | UInt(8) => 1 // char
    Int(16) | UInt(16) => 2 // short
    Int(32) | UInt(32) => 4 // int
    Int(64) | UInt(64) => 8 // long
    FP(32) => 4 // float
    FP(64) => 8 // double
    Ptr(_) => 8 // pointer (assume 64-bit)
    Array(elem_type, count) => {
      let elem_size = self.calculate_type_size(elem_type)
      elem_size * count
    }
    Struct(_, fields) => {
      let mut total_size = 0
      let mut max_alignment = 1

      // Calculate size with alignment for each field
      for field in fields {
        let (_, field_type) = field
        let field_size = self.calculate_type_size(field_type)
        let field_alignment = self.calculate_type_alignment(field_type)

        // Update maximum alignment requirement
        if field_alignment > max_alignment {
          max_alignment = field_alignment
        }

        // Align current position to field alignment
        if total_size % field_alignment != 0 {
          total_size = (total_size / field_alignment + 1) * field_alignment
        }

        // Add field size
        total_size = total_size + field_size
      }

      // Align total struct size to the maximum alignment requirement
      if total_size % max_alignment != 0 {
        total_size = (total_size / max_alignment + 1) * max_alignment
      }
      total_size
    }
    Void => 0
    _ => 4 // Default fallback
  }
}

///|
fn FuncCodeGenContext::calculate_type_alignment(self : Self, ty : Type) -> Int {
  match ty {
    Int(1) | UInt(1) => 1 // bool
    Int(8) | UInt(8) => 1 // char
    Int(16) | UInt(16) => 2 // short
    Int(32) | UInt(32) => 4 // int
    Int(64) | UInt(64) => 8 // long
    FP(32) => 4 // float
    FP(64) => 8 // double
    Ptr(_) => 8 // pointer (assume 64-bit)
    Array(elem_type, _) => self.calculate_type_alignment(elem_type)
    Struct(_, fields) => {
      let mut max_alignment = 1
      for field in fields {
        let (_, field_type) = field
        let field_alignment = self.calculate_type_alignment(field_type)
        if field_alignment > max_alignment {
          max_alignment = field_alignment
        }
      }
      max_alignment
    }
    _ => 4 // Default fallback
  }
}

///|
fn FuncCodeGenContext::get_next_block_id(self : Self) -> Int {
  let id = self.block_counter
  self.block_counter = self.block_counter + 1
  id
}

///|
fn FuncCodeGenContext::emit_function_body(self : Self) -> Unit raise {
  let compound_statement = self.func_def.body
  // Entry block and insert point are already set up
  self.emit_compound_statement(compound_statement)

  // For void functions, always add implicit return at the end
  // (LLVM will optimize away unreachable returns)
  match self.return_type {
    Void =>
      // For void functions, add implicit return
      ignore(self.builder.createRetVoid())
    _ => ()
    // For non-void functions, the C standard requires an explicit return
    // We'll let the user handle this case
  }
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
    LabeledStatement(labeled_stmt) => self.emit_labeled_statement(labeled_stmt)
    ExpressionStatement(expr) => self.emit_expr_stat(expr)
    SelectionStatement(sel_stmt) => self.emit_selection_statement(sel_stmt)
    IterationStatement(iter_stmt) => self.emit_iteration_statement(iter_stmt)
    JumpStatement(jump_stmt) => self.emit_jump_statement(jump_stmt)
    CompoundStatement(comp_stmt) => self.emit_compound_statement(comp_stmt)
  }
}

///|
fn FuncCodeGenContext::emit_statement_with_terminator_check(
  self : Self,
  stmt : Statement,
) -> Bool raise {
  match stmt {
    Empty => false
    LabeledStatement(labeled_stmt) => {
      self.emit_labeled_statement(labeled_stmt)
      false // labeled statements typically don't terminate
    }
    ExpressionStatement(expr) => {
      self.emit_expr_stat(expr)
      false
    }
    SelectionStatement(sel_stmt) => {
      self.emit_selection_statement(sel_stmt)
      false // selection statements are handled specially
    }
    IterationStatement(iter_stmt) => {
      self.emit_iteration_statement(iter_stmt)
      false
    }
    JumpStatement(jump_stmt) => {
      self.emit_jump_statement(jump_stmt)
      true // jump statements always terminate
    }
    CompoundStatement(comp_stmt) => {
      // Check if any statement in the compound statement terminates
      for item in comp_stmt.items {
        match item {
          Statement(stmt) =>
            if self.emit_statement_with_terminator_check(stmt) {
              return true
            }
          Declaration(decl) => self.emit_declaration(decl)
        }
      }
      false
    }
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
            ty =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for AddAssign. \{ty}",
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
            ty =>
              raise CodeGenError::UnSupportFeature(
                "Unsupported type for SubAssign. \{ty}",
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

  // If there's only one expression, evaluate it directly
  if logical_and_exprs.length() == 1 {
    return self.emit_logical_and_expr(logical_and_exprs[0])
  }

  // For multiple expressions, implement short-circuit evaluation
  // Create result variable and basic blocks
  let result_alloca = self.builder.createAlloca(
    self.global_ctx.llvm_ctx.getInt1Ty(),
    name="or_result",
  )
  let continue_bb = self.func_value.addBasicBlock(name="or.continue")
  let end_bb = self.func_value.addBasicBlock(name="or.end")

  // Evaluate first expression
  let (first_ty, first_val) = self.emit_logical_and_expr(logical_and_exprs[0])
  let bool_val = if first_ty != Int(1) && first_ty != UInt(1) {
    let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
    self.builder.createICmpNE(first_val, zero)
  } else {
    first_val
  }

  // Store the result and check if we should short-circuit
  let _ = self.builder.createStore(bool_val, result_alloca)
  let _ = self.builder.createCondBr(bool_val, end_bb, continue_bb)

  // Continue block for remaining expressions
  let mut current_bb = continue_bb
  for i in 1..<logical_and_exprs.length() {
    self.builder.setInsertPoint(current_bb)
    let (ty, val) = self.emit_logical_and_expr(logical_and_exprs[i])
    let bool_val = if ty != Int(1) && ty != UInt(1) {
      let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
      self.builder.createICmpNE(val, zero)
    } else {
      val
    }

    // Store the result
    let _ = self.builder.createStore(bool_val, result_alloca)
    if i == logical_and_exprs.length() - 1 {
      // Last expression, just jump to end
      let _ = self.builder.createBr(end_bb)

    } else {
      // Create next continue block
      let next_bb = self.func_value.addBasicBlock(name="or.continue.\{i}")
      let _ = self.builder.createCondBr(bool_val, end_bb, next_bb)
      current_bb = next_bb
    }
  }

  // End block - load the final result
  self.builder.setInsertPoint(end_bb)
  let result = self.builder.createLoad(
    self.global_ctx.llvm_ctx.getInt1Ty(),
    result_alloca,
  )
  (Int(1), result)
}

///|
fn FuncCodeGenContext::emit_logical_and_expr(
  self : Self,
  log_and_expr : LogicalAndExpr,
) -> (Type, &LLVMValue) raise {
  let { exprs: inclusive_or_exprs } = log_and_expr

  // If there's only one expression, evaluate it directly
  if inclusive_or_exprs.length() == 1 {
    return self.emit_inclusive_or_expr(inclusive_or_exprs[0])
  }

  // For multiple expressions, implement short-circuit evaluation
  // Create result variable and basic blocks
  let result_alloca = self.builder.createAlloca(
    self.global_ctx.llvm_ctx.getInt1Ty(),
    name="and_result",
  )
  let continue_bb = self.func_value.addBasicBlock(name="and.continue")
  let end_bb = self.func_value.addBasicBlock(name="and.end")

  // Evaluate first expression
  let (first_ty, first_val) = self.emit_inclusive_or_expr(inclusive_or_exprs[0])
  let bool_val = if first_ty != Int(1) && first_ty != UInt(1) {
    let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
    self.builder.createICmpNE(first_val, zero)
  } else {
    first_val
  }

  // Store the result and check if we should short-circuit
  ignore(self.builder.createStore(bool_val, result_alloca))
  ignore(self.builder.createCondBr(bool_val, continue_bb, end_bb))

  // Continue block for remaining expressions
  let mut current_bb = continue_bb
  for i in 1..<inclusive_or_exprs.length() {
    self.builder.setInsertPoint(current_bb)
    let (ty, val) = self.emit_inclusive_or_expr(inclusive_or_exprs[i])
    let bool_val = if ty != Int(1) && ty != UInt(1) {
      let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
      self.builder.createICmpNE(val, zero)
    } else {
      val
    }

    // Store the result
    let _ = self.builder.createStore(bool_val, result_alloca)
    if i == inclusive_or_exprs.length() - 1 {
      // Last expression, just jump to end
      let _ = self.builder.createBr(end_bb)

    } else {
      // Create next continue block
      let next_bb = self.func_value.addBasicBlock(name="and.continue.\{i}")
      let _ = self.builder.createCondBr(bool_val, next_bb, end_bb)
      current_bb = next_bb
    }
  }

  // End block - load the final result
  self.builder.setInsertPoint(end_bb)
  let result = self.builder.createLoad(
    self.global_ctx.llvm_ctx.getInt1Ty(),
    result_alloca,
  )
  (Int(1), result)
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

    // For simplicity, handle the most common cases for linked_list.c
    let op = ops[i - 1]
    let result = match (op, first_ty, ty) {
      // Floating point comparisons
      (EQ, FP(_), FP(_)) => self.builder.createFCmpOEQ(first_val, val)
      (NE, FP(_), FP(_)) => self.builder.createFCmpONE(first_val, val)

      // Integer comparisons (same type)
      (EQ, Int(_), Int(_)) | (EQ, UInt(_), UInt(_)) =>
        self.builder.createICmpEQ(first_val, val)
      (NE, Int(_), Int(_)) | (NE, UInt(_), UInt(_)) =>
        self.builder.createICmpNE(first_val, val)

      // Pointer comparisons (same type)
      //(EQ, Ptr(_), Ptr(_)) => self.builder.createICmpEQ(first_val, val)
      (EQ, Ptr(_), Ptr(_)) => {
        let int_val1 = self.builder.createPtrToInt(
          first_val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let int_val2 = self.builder.createPtrToInt(
          val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        self.builder.createICmpEQ(int_val1, int_val2)
      }
      //(NE, Ptr(_), Ptr(_)) => self.builder.createICmpNE(first_val, val)
      (NE, Ptr(_), Ptr(_)) => {
        let int_val1 = self.builder.createPtrToInt(
          first_val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let int_val2 = self.builder.createPtrToInt(
          val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        self.builder.createICmpNE(int_val1, int_val2)
      }

      // Pointer to null (integer 0) comparison - convert pointer to int for comparison
      (EQ, Ptr(_), Int(_)) | (EQ, Ptr(_), UInt(_)) => {
        // Convert pointer to integer for comparison (simpler approach)
        let int_val = self.builder.createPtrToInt(
          first_val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let val_64 = self.emit_cast(from_type=ty, to_type=Int(64), val)
        self.builder.createICmpEQ(int_val, val_64)
      }
      (NE, Ptr(_), Int(_)) | (NE, Ptr(_), UInt(_)) => {
        // Convert pointer to integer for comparison
        let int_val = self.builder.createPtrToInt(
          first_val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let val_64 = self.emit_cast(from_type=ty, to_type=Int(64), val)
        self.builder.createICmpNE(int_val, val_64)
      }
      (EQ, Int(_), Ptr(_)) | (EQ, UInt(_), Ptr(_)) => {
        // Convert pointer to integer for comparison
        let int_val = self.builder.createPtrToInt(
          val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let first_val_64 = self.emit_cast(
          from_type=first_ty,
          to_type=Int(64),
          first_val,
        )
        self.builder.createICmpEQ(first_val_64, int_val)
      }
      (NE, Int(_), Ptr(_)) | (NE, UInt(_), Ptr(_)) => {
        // Convert pointer to integer for comparison
        let int_val = self.builder.createPtrToInt(
          val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let first_val_64 = self.emit_cast(
          from_type=first_ty,
          to_type=Int(64),
          first_val,
        )
        self.builder.createICmpNE(first_val_64, int_val)
      }

      // Mixed integer types - cast to common type
      (EQ, Int(_), UInt(_)) | (EQ, UInt(_), Int(_)) => {
        let casted_val = self.emit_cast(from_type=ty, to_type=first_ty, val)
        self.builder.createICmpEQ(first_val, casted_val)
      }
      (NE, Int(_), UInt(_)) | (NE, UInt(_), Int(_)) => {
        let casted_val = self.emit_cast(from_type=ty, to_type=first_ty, val)
        self.builder.createICmpNE(first_val, casted_val)
      }
      _ =>
        raise CodeGenError::UnSupportFeature(
          "Unsupported equality comparison between \{first_ty} and \{ty}",
        )
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

    // For simplicity, handle the most common cases for linked_list.c
    let op = ops[i - 1]
    let result = match (op, first_ty, ty) {
      // Floating point comparisons
      (LT, FP(_), FP(_)) => self.builder.createFCmpOLT(first_val, val)
      (GT, FP(_), FP(_)) => self.builder.createFCmpOGT(first_val, val)
      (LE, FP(_), FP(_)) => self.builder.createFCmpOLE(first_val, val)
      (GE, FP(_), FP(_)) => self.builder.createFCmpOGE(first_val, val)

      // Signed integer comparisons (same type)
      (LT, Int(_), Int(_)) => self.builder.createICmpSLT(first_val, val)
      (GT, Int(_), Int(_)) => self.builder.createICmpSGT(first_val, val)
      (LE, Int(_), Int(_)) => self.builder.createICmpSLE(first_val, val)
      (GE, Int(_), Int(_)) => self.builder.createICmpSGE(first_val, val)

      // Unsigned integer comparisons (same type)
      (LT, UInt(_), UInt(_)) => self.builder.createICmpULT(first_val, val)
      (GT, UInt(_), UInt(_)) => self.builder.createICmpUGT(first_val, val)
      (LE, UInt(_), UInt(_)) => self.builder.createICmpULE(first_val, val)
      (GE, UInt(_), UInt(_)) => self.builder.createICmpUGE(first_val, val)

      // Pointer comparisons (same type)
      (LT, Ptr(_), Ptr(_)) => self.builder.createICmpULT(first_val, val)
      (GT, Ptr(_), Ptr(_)) => self.builder.createICmpUGT(first_val, val)
      (LE, Ptr(_), Ptr(_)) => self.builder.createICmpULE(first_val, val)
      (GE, Ptr(_), Ptr(_)) => self.builder.createICmpUGE(first_val, val)

      // Mixed integer types - cast to common type
      (LT, Int(_), UInt(_)) | (LT, UInt(_), Int(_)) => {
        let casted_val = self.emit_cast(from_type=ty, to_type=first_ty, val)
        self.builder.createICmpSLT(first_val, casted_val)
      }
      (GT, Int(_), UInt(_)) | (GT, UInt(_), Int(_)) => {
        let casted_val = self.emit_cast(from_type=ty, to_type=first_ty, val)
        self.builder.createICmpSGT(first_val, casted_val)
      }
      (LE, Int(_), UInt(_)) | (LE, UInt(_), Int(_)) => {
        let casted_val = self.emit_cast(from_type=ty, to_type=first_ty, val)
        self.builder.createICmpSLE(first_val, casted_val)
      }
      (GE, Int(_), UInt(_)) | (GE, UInt(_), Int(_)) => {
        let casted_val = self.emit_cast(from_type=ty, to_type=first_ty, val)
        self.builder.createICmpSGE(first_val, casted_val)
      }
      _ =>
        raise CodeGenError::UnSupportFeature(
          "Unsupported relational comparison between \{first_ty} and \{ty}",
        )
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
              "Unsupported type for Plus operation: \{first_ty}",
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
    .any(fn(op) { op is PlusPlus || op is MinusMinus })
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
        // Calculate size manually for now due to LLVM DataLayout issues
        // Special handling: for sizeof, we need the original type before array-to-pointer decay
        let sizeof_type = self.get_sizeof_type_from_unary_body(unary_expr.body)
        let size_bytes = self.calculate_type_size(sizeof_type)
        expr_value = self.global_ctx.llvm_ctx.getConstInt32(size_bytes)
        expr_type = Int(32)
      }
    }
  }
  (expr_type, expr_value)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_unary_body(
  self : Self,
  unary_body : UnaryExprBody,
) -> Type raise {
  // Get the original type of an expression for sizeof calculation
  // This function does NOT perform array-to-pointer decay
  match unary_body {
    PostFix(postfix_expr) =>
      self.get_sizeof_type_from_postfix_expr(postfix_expr)
    UnaryOp(op, cast_expr) =>
      match op {
        AddressOf => {
          // &expr: get type of expr and return Ptr(type)
          let expr_type = self.get_sizeof_type_from_cast_expr(cast_expr)
          Ptr(expr_type)
        }
        Dereference => {
          // *expr: get type of expr and dereference it
          let expr_type = self.get_sizeof_type_from_cast_expr(cast_expr)
          match expr_type {
            Ptr(pointed_type) => pointed_type
            Array(elem_type, _) => elem_type
            _ =>
              raise CodeGenError::UnSupportFeature(
                "Cannot dereference non-pointer type \{expr_type}",
              )
          }
        }
        _ =>
          // For other operators, get the operand type
          self.get_sizeof_type_from_cast_expr(cast_expr)
      }
    SizeofTypeName(type_name) =>
      // sizeof(type): get type from type name
      self.global_ctx.analysis_typename(type_name)
    AlignOfTypeName(type_name) =>
      // _Alignof(type): get type from type name
      self.global_ctx.analysis_typename(type_name)
  }
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_postfix_expr(
  self : Self,
  post_expr : PostFixExpr,
) -> Type raise {
  // Get original type from postfix expression (without array-to-pointer decay)
  let base_type = match post_expr.head {
    Left(prim_expr) => self.get_sizeof_type_from_prim_expr(prim_expr)
    Right(_) =>
      raise CodeGenError::UnSupportFeature(
        "Compound literals not supported in sizeof",
      )
  }

  // Apply suffixes to the type
  let mut current_type = base_type
  for suffix in post_expr.suffixes {
    current_type = match suffix {
      Indexing(_) =>
        // arr[index]: if arr is Array(T, n), result is T; if arr is Ptr(T), result is T
        match current_type {
          Array(elem_type, _) => elem_type
          Ptr(pointed_type) => pointed_type
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Cannot index non-array/non-pointer type in sizeof",
            )
        }
      DotAccess(field_name) =>
        // struct.field: get field type
        match current_type {
          Struct(_, fields) => {
            let mut found_field : (String, Type)? = None
            for field in fields {
              if field.0 == field_name {
                found_field = Some(field)
                break
              }
            }
            match found_field {
              Some((_, field_type)) => field_type
              None =>
                raise CodeGenError::UnSupportFeature(
                  "Field \{field_name} not found in struct",
                )
            }
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Cannot access field of non-struct type in sizeof",
            )
        }
      ArrowAccess(field_name) =>
        // ptr->field: dereference pointer then get field type
        match current_type {
          Ptr(Struct(_, fields)) => {
            let mut found_field : (String, Type)? = None
            for field in fields {
              if field.0 == field_name {
                found_field = Some(field)
                break
              }
            }
            match found_field {
              Some((_, field_type)) => field_type
              None =>
                raise CodeGenError::UnSupportFeature(
                  "Field \{field_name} not found in struct",
                )
            }
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Cannot arrow-access field of non-pointer-to-struct type in sizeof",
            )
        }
      Call(_) =>
        // func(): need to look up function return type
        raise CodeGenError::UnSupportFeature(
          "Function calls not supported in sizeof",
        )
      PlusPlus | MinusMinus =>
        // ++/-- operators don't change the type
        current_type
    }
  }
  current_type
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_prim_expr(
  self : Self,
  prim_expr : PrimExpr,
) -> Type raise {
  // Get original type from primary expression (without array-to-pointer decay)
  match prim_expr {
    Identifier(name) =>
      // Look up variable and return its ORIGINAL type (not decayed)
      match self.var_env.get(name) {
        Some((ty, _, _)) => ty // Return original type, not decayed
        None =>
          // Check global variable environment
          match self.global_ctx.global_var_env.get(name) {
            Some((_, global_type)) => global_type // Return original type
            None =>
              raise CodeGenError::UnSupportFeature(
                "Undefined variable in sizeof: \{name}",
              )
          }
      }
    Constant(constant) =>
      // Return type of constant
      match constant {
        Int(_) => Int(32)
        Long(_) => Int(64)
        UInt(_) => UInt(32)
        ULong(_) => UInt(64)
        Float(_) => FP(32)
        Double(_) => FP(64)
        Char(_) => Int(8)
      }
    StringLiteral(s) =>
      // String literal: array of char
      Array(Int(8), s.length() + 1) // +1 for null terminator
    ParenExpr(expr) =>
      // Parenthesized expression
      self.get_sizeof_type_from_expr(expr)
    BuiltinOffsetof(_, _) =>
      // __builtin_offsetof returns size_t, which we treat as Int(32)
      Int(32)
    GCCExtBlock(_) =>
      raise CodeGenError::UnSupportFeature(
        "GCC extension blocks not supported in sizeof",
      )
  }
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_cast_expr(
  self : Self,
  cast_expr : CastExpr,
) -> Type raise {
  match cast_expr {
    UnaryExpr(unary_expr) => self.get_sizeof_type_from_unary_expr(unary_expr)
    Cast(type_name, _) =>
      // Cast: return the target type
      self.global_ctx.analysis_typename(type_name)
  }
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_unary_expr(
  self : Self,
  unary_expr : UnaryExpr,
) -> Type raise {
  // For sizeof type calculation, ignore prefixes and get type from body
  self.get_sizeof_type_from_unary_body(unary_expr.body)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_expr(
  self : Self,
  expr : Expr,
) -> Type raise {
  // Get type from first assignment expression in the expr
  let first_assign_expr = expr.exprs[0]
  self.get_sizeof_type_from_assign_expr(first_assign_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_assign_expr(
  self : Self,
  assign_expr : AssignExpr,
) -> Type raise {
  match assign_expr {
    Conditional(cond) => self.get_sizeof_type_from_conditional_expr(cond)
    Assign(_, _, _) =>
      // For assignment, just get type from the RHS for simplicity
      raise CodeGenError::UnSupportFeature(
        "Assignment expressions not supported in sizeof",
      )
  }
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_conditional_expr(
  self : Self,
  cond_expr : ConditionalExpr,
) -> Type raise {
  // For conditional expressions, we need to evaluate further down
  // For now, just get type from the main expression
  self.get_sizeof_type_from_logical_or_expr(cond_expr.expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_logical_or_expr(
  self : Self,
  log_or_expr : LogicalOrExpr,
) -> Type raise {
  // Get type from first logical AND expression
  let first_expr = log_or_expr.exprs[0]
  self.get_sizeof_type_from_logical_and_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_logical_and_expr(
  self : Self,
  log_and_expr : LogicalAndExpr,
) -> Type raise {
  // Get type from first inclusive OR expression
  let first_expr = log_and_expr.exprs[0]
  self.get_sizeof_type_from_inclusive_or_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_inclusive_or_expr(
  self : Self,
  inc_or_expr : InclusiveOrExpr,
) -> Type raise {
  // Get type from first exclusive OR expression
  let first_expr = inc_or_expr.exprs[0]
  self.get_sizeof_type_from_exclusive_or_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_exclusive_or_expr(
  self : Self,
  exc_or_expr : ExclusiveOrExpr,
) -> Type raise {
  // Get type from first AND expression
  let first_expr = exc_or_expr.exprs[0]
  self.get_sizeof_type_from_and_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_and_expr(
  self : Self,
  and_expr : AndExpr,
) -> Type raise {
  // Get type from first equality expression
  let first_expr = and_expr.exprs[0]
  self.get_sizeof_type_from_eq_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_eq_expr(
  self : Self,
  eq_expr : EqualityExpr,
) -> Type raise {
  // Get type from first relational expression
  let first_expr = eq_expr.exprs[0]
  self.get_sizeof_type_from_rel_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_rel_expr(
  self : Self,
  rel_expr : RelationalExpr,
) -> Type raise {
  // Get type from first shift expression
  let first_expr = rel_expr.exprs[0]
  self.get_sizeof_type_from_shift_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_shift_expr(
  self : Self,
  shift_expr : ShiftExpr,
) -> Type raise {
  // Get type from first additive expression
  let first_expr = shift_expr.exprs[0]
  self.get_sizeof_type_from_addsub_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_addsub_expr(
  self : Self,
  add_expr : AddSubExpr,
) -> Type raise {
  // Get type from first multiplicative expression
  let first_expr = add_expr.exprs[0]
  self.get_sizeof_type_from_mult_expr(first_expr)
}

///|
fn FuncCodeGenContext::get_sizeof_type_from_mult_expr(
  self : Self,
  mult_expr : MultExpr,
) -> Type raise {
  // Get type from first cast expression
  let first_expr = mult_expr.exprs[0]
  self.get_sizeof_type_from_cast_expr(first_expr)
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
                  //// For floating point, use FSub with zero constant
                  let zero = match operand_type {
                    FP(32) => self.global_ctx.llvm_ctx.getConstFloat(0)
                    FP(64) => self.global_ctx.llvm_ctx.getConstDouble(0)
                    _ => self.global_ctx.llvm_ctx.getConstFloat(0) // Fallback
                  }
                  let negated = self.builder.createFSub(zero, operand_value)
                  //let negated = self.builder.createFNeg(operand_value)
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
            LogicalNot =>
              // Logical NOT: compare with zero
              match operand_type {
                Ptr(_) => {
                  // For pointers, convert to integer first, then compare
                  let ptr_as_int = self.builder.createPtrToInt(
                    operand_value,
                    self.global_ctx.llvm_ctx.getInt64Ty(),
                  )
                  let zero = self.global_ctx.llvm_ctx.getConstInt64(0)
                  let is_zero = self.builder.createICmpEQ(ptr_as_int, zero)
                  (Int(1), is_zero)
                }
                FP(_) => {
                  let zero = self.global_ctx.llvm_ctx.getConstDouble(0.0)
                    as &LLVMValue
                  let is_zero = self.builder.createFCmpOEQ(operand_value, zero)
                  (Int(1), is_zero)
                }
                _ => {
                  // For integers
                  let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
                    as &LLVMValue
                  let is_zero = self.builder.createICmpEQ(operand_value, zero)
                  (Int(1), is_zero)
                }
              }
          }
        }
      }
    SizeofTypeName(type_name) => {
      // Sizeof type: get size of specified type
      let expr_type = self.global_ctx.analysis_typename(type_name)
      // Calculate size manually for now due to LLVM DataLayout issues
      let size_bytes = self.calculate_type_size(expr_type)
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

  // Check if we have dot access (struct.field) - needs lvalue
  let has_dot_access = post_expr.suffixes
    .iter()
    .any(fn(suffix) {
      match suffix {
        DotAccess(_) => true
        _ => false
      }
    })

  // Check if we have arrow access (ptr->field) - needs rvalue
  let has_arrow_access = post_expr.suffixes
    .iter()
    .any(fn(suffix) {
      match suffix {
        ArrowAccess(_) => true
        _ => false
      }
    })

  // Evaluate the head of the postfix expression
  let (expr_type_init, expr_value_init) = match post_expr.head {
    Left(prim_expr) =>
      if has_arrow_access {
        // For arrow access, we MUST use rvalue (load the pointer value)
        // This takes priority over dot access because ptr->field[idx].member
        // needs the pointer loaded first
        self.emit_prim_expr(prim_expr)
      } else if has_increment_decrement || has_dot_access {
        // For ++/-- operators or dot access, we need the lvalue (address) of the head
        // However, for pointer types, we should first check if this is a pointer parameter
        // that needs to be loaded before proceeding with array access
        match prim_expr {
          Identifier(name) =>
            // Check if this is a pointer parameter that needs special handling
            match self.var_env.get(name) {
              Some((Ptr(_), _, false)) =>
                // This is a pointer parameter stored in alloca
                // Even with dot access, we need to load the pointer first for array indexing
                self.emit_prim_expr(prim_expr)
              _ => self.emit_prim_expr_as_lvalue(prim_expr)
            }
          _ => self.emit_prim_expr_as_lvalue(prim_expr)
        }
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

  // Track if current expr_value is an address (lvalue) or value (rvalue)
  let mut is_lvalue = has_increment_decrement || has_dot_access

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
            match pointed_type {
              Array(elem_type, _) => {
                // For pointer to array: ptr[index] gives us the indexed array
                // The result should be a pointer to the first element of that array
                // For example: int (*p)[3]; p[i] gives int*, not int
                expr_type = Ptr(elem_type)
                expr_value = gep
              }
              _ =>
                // For pointer to scalar:
                // Check if we need address for subsequent dot access
                if has_dot_access {
                  // Return address for potential subsequent dot access
                  expr_type = pointed_type
                  expr_value = gep
                } else {
                  // For pointer to scalar: load the value
                  let loaded_value = self.builder.createLoad(
                    elem_llvm_type, gep,
                  )
                  expr_type = pointed_type
                  expr_value = loaded_value
                }
            }
          }
          Array(elem_type, _) => {
            // For array indexing: arr[index]
            let elem_llvm_type = self.global_ctx.convert_type_to_llvm(elem_type)
            let array_llvm_type = self.global_ctx.convert_type_to_llvm(
              expr_type,
            )
            let gep = self.builder.createGEP(expr_value, array_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // Array base
              index_value, // Index into array
            ])
            match elem_type {
              Array(inner_elem_type, _) => {
                // If element is also an array, decay to pointer to the inner element type
                // For char strs[][16], strs[0] should be char*, not char(*)[16]
                let ptr_to_inner = Ptr(inner_elem_type)
                expr_type = ptr_to_inner

                // Need an additional GEP to get pointer to first element of the sub-array
                let sub_array_gep = self.builder.createGEP(
                  gep,
                  elem_llvm_type,
                  [self.global_ctx.llvm_ctx.getConstInt32(0)], // First element of sub-array
                )
                expr_value = sub_array_gep
              }
              _ =>
                // For scalar elements in arrays:
                // If this expression has dot access anywhere in its suffixes,
                // we may need to return address instead of value
                if has_dot_access {
                  // Return address for potential subsequent dot access
                  expr_type = elem_type
                  expr_value = gep
                } else {
                  // For scalar elements, load the value
                  let loaded_value = self.builder.createLoad(
                    elem_llvm_type, gep,
                  )
                  expr_type = elem_type
                  expr_value = loaded_value
                }
            }
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
        // Handle struct field access: struct.field
        // The expr_value should be the address of the struct (lvalue)
        match expr_type {
          Struct(struct_name, fields) => {
            let field_idx = fields.search_by(pair => pair.0 == field_name)
            let field_idx = match field_idx {
              Some(idx) => idx
              None =>
                raise CodeGenError::SyntaxError(
                  "Field \{field_name} not found in struct \{struct_name}",
                )
            }
            let (_, field_type) = fields[field_idx]
            let field_llvm_type = self.global_ctx.convert_type_to_llvm(
              field_type,
            )
            let struct_llvm_type = self.global_ctx.convert_type_to_llvm(
              expr_type,
            )
            // Ensure expr_value is a pointer for GEP instruction
            let gep = self.builder.createGEP(expr_value, struct_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // struct base
              self.global_ctx.llvm_ctx.getConstInt32(field_idx), // field index
            ])
            match field_type {
              Array(elem_type, _) => {
                // For array fields, return pointer to first element (array decay)
                expr_type = Ptr(elem_type)
                expr_value = gep
              }
              _ => {
                // For non-array fields, load the value
                let loaded_value = self.builder.createLoad(field_llvm_type, gep)
                expr_type = field_type
                expr_value = loaded_value
              }
            }
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Dot access only supported on struct types, got \{expr_type}",
            )
        }
      ArrowAccess(field_name) =>
        // Handle pointer field access: ptr->field
        // This is equivalent to (*ptr).field
        // Note: expr_value should already be a pointer value (loaded from a pointer variable)
        match expr_type {
          Ptr(Struct(struct_name, field_types)) => {
            let field_idx = field_types.search_by(pair => pair.0 == field_name)
            let field_idx = match field_idx {
              Some(idx) => idx
              None =>
                raise CodeGenError::UnSupportFeature(
                  "Field \{field_name} not found in struct \{struct_name}",
                )
            }
            let (_, field_type) = field_types[field_idx]
            let field_llvm_type = self.global_ctx.convert_type_to_llvm(
              field_type,
            )
            let struct_llvm_type = self.global_ctx.convert_type_to_llvm(
              Struct(struct_name, field_types),
            )
            // expr_value is the pointer value, use it directly for GEP
            let gep = self.builder.createGEP(expr_value, struct_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // struct base
              self.global_ctx.llvm_ctx.getConstInt32(field_idx), // field index
            ])
            match field_type {
              Array(elem_type, _) => {
                // For array fields, return pointer to first element (array decay)
                expr_type = Ptr(elem_type)
                expr_value = gep
                is_lvalue = false // Arrays decay to pointers, so they're rvalues
              }
              _ => {
                expr_type = field_type
                // Check if we need the address for subsequent operations
                if has_increment_decrement {
                  // For increment/decrement, we need the address, not the value
                  expr_value = gep
                  is_lvalue = true
                } else {
                  // For other operations, load the value
                  let loaded_value = self.builder.createLoad(
                    field_llvm_type, gep,
                  )
                  expr_value = loaded_value
                  is_lvalue = false
                }
              }
            }
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Arrow access only supported on pointer to struct types, got \{expr_type}",
            )
        }
      PlusPlus =>
        // Post-increment: return old value, increment stored value
        match expr_type {
          Int(_) | UInt(_) => {
            // expr_value should be an address for post-increment
            if !is_lvalue {
              raise CodeGenError::UnSupportFeature(
                "Post-increment requires lvalue, but got rvalue",
              )
            }
            let llvm_type = self.global_ctx.convert_type_to_llvm(expr_type)
            let old_val = self.builder.createLoad(llvm_type, expr_value)
            let one = self.global_ctx.llvm_ctx.getConstInt32(1)
            let new_val = self.builder.createAdd(old_val, one)
            ignore(self.builder.createStore(new_val, expr_value))
            expr_value = old_val // Return old value
            is_lvalue = false // Result is now a value
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
            // expr_value should be an address for post-decrement
            if !is_lvalue {
              raise CodeGenError::UnSupportFeature(
                "Post-decrement requires lvalue, but got rvalue",
              )
            }
            let llvm_type = self.global_ctx.convert_type_to_llvm(expr_type)
            let old_val = self.builder.createLoad(llvm_type, expr_value)
            let one = self.global_ctx.llvm_ctx.getConstInt32(1)
            let new_val = self.builder.createSub(old_val, one)
            ignore(self.builder.createStore(new_val, expr_value))
            expr_value = old_val // Return old value
            is_lvalue = false // Result is now a value
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
            // For array variables, decay to pointer to first element
            match ty {
              Array(elem_type, _) => {
                let ptr_type = Ptr(elem_type)
                (ptr_type, alloca_value)
              }
              _ => (ty, alloca_value) // shouldn't happen
            }
          } else {
            // For normal variables (including pointer variables), load the value
            let llvm_type = self.global_ctx.convert_type_to_llvm(ty)
            let loaded_value = self.builder.createLoad(llvm_type, alloca_value)
            (ty, loaded_value)
          }
        None =>
          // Check global variable environment
          match self.global_ctx.global_var_env.get(name) {
            Some((global_var, global_type)) =>
              // For global variables, return the global variable itself (which is a pointer)
              match global_type {
                Array(elem_type, _) =>
                  // For global arrays, don't decay to pointer immediately
                  // Keep the array type so GEP can use correct indexing
                  (global_type, global_var)
                _ =>
                  // For other global variables, return them as lvalue addresses
                  (global_type, global_var)
              }
            None =>
              raise CodeGenError::UnSupportFeature(
                "Undefined variable: \{name}",
              )
          }
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
    //raise CodeGenError::UnSupportFeature(
    //  "String literals not implemented yet",
    //)
    StringLiteral(s) => {
      let str = self.builder.createGlobalString(s)
      (Ptr(Int(8)), str) // char*
    }
    ParenExpr(expr) =>
      // Parenthesized expression - just evaluate the inner expression
      self.emit_expr(expr)
    BuiltinOffsetof(_) =>
      raise CodeGenError::UnSupportFeature(
        "Builtin offsetof not implemented yet",
      )
    GCCExtBlock(_) =>
      raise CodeGenError::UnSupportFeature("GCC extension blocks not supported")
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
  // Check if we have arrow access (ptr->field) - needs special handling
  let has_arrow_access = post_expr.suffixes
    .iter()
    .any(fn(suffix) {
      match suffix {
        ArrowAccess(_) => true
        _ => false
      }
    })

  // Start with the head of the postfix expression
  let (expr_type_init, expr_value_init) = match post_expr.head {
    Left(prim_expr) =>
      if has_arrow_access {
        // For arrow access, we need the loaded pointer value, not the address
        self.emit_prim_expr(prim_expr)
      } else {
        // For other cases, we need the lvalue (address)
        self.emit_prim_expr_as_lvalue(prim_expr)
      }
    Right(_) =>
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
        let (_, index_value) = self.emit_expr(index_expr)
        match expr_type {
          Ptr(pointed_type) => {
            // For pointer indexing: ptr[index]
            // We need to load the pointer value first since expr_value is the alloca address
            let ptr_llvm_type = self.global_ctx.llvm_ctx.getPtrTy()
            let ptr_value = self.builder.createLoad(ptr_llvm_type, expr_value)
              as &LLVMValue
            let elem_llvm_type = self.global_ctx.convert_type_to_llvm(
              pointed_type,
            )
            let gep = self.builder.createGEP(ptr_value, elem_llvm_type, [
              index_value,
            ])
            expr_type = pointed_type
            expr_value = gep // Return address, not loaded value
          }
          Array(elem_type, _) => {
            // For array lvalue indexing: return the address of arr[index]
            let array_llvm_type = self.global_ctx.convert_type_to_llvm(
              expr_type,
            )
            let gep = self.builder.createGEP(expr_value, array_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // Array base
              index_value, // Index into array
            ])
            expr_type = elem_type
            expr_value = gep // Return address, not loaded value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Array indexing not supported for type \{expr_type}",
            )
        }
      }
      DotAccess(field_name) =>
        // Handle struct field access as lvalue: struct.field
        match expr_type {
          Struct(struct_name, field_types) => {
            let field_idx = field_types.search_by(pair => pair.0 == field_name)
            let field_index = match field_idx {
              Some(idx) => idx
              None =>
                raise CodeGenError::UnSupportFeature(
                  "Field \{field_name} not found in struct \{struct_name}",
                )
            }
            let (_, field_type) = field_types[field_index]
            let struct_llvm_type = self.global_ctx.convert_type_to_llvm(
              expr_type,
            )
            // Create GEP instruction to get the address of the field
            let gep = self.builder.createGEP(expr_value, struct_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // struct base
              self.global_ctx.llvm_ctx.getConstInt32(field_index), // field index
            ])
            expr_type = field_type
            expr_value = gep // Return address, not loaded value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Dot access only supported on struct types",
            )
        }
      ArrowAccess(field_name) =>
        // Handle pointer field access as lvalue: ptr->field
        // This is equivalent to &((*ptr).field)
        match expr_type {
          Ptr(Struct(struct_name, field_types)) => {
            let field_idx = field_types.search_by(pair => pair.0 == field_name)
            let field_idx = match field_idx {
              Some(idx) => idx
              None =>
                raise CodeGenError::UnSupportFeature(
                  "Field \{field_name} not found in struct \{struct_name}",
                )
            }
            let (_, field_type) = field_types[field_idx]
            let struct_llvm_type = self.global_ctx.convert_type_to_llvm(
              Struct(struct_name, field_types),
            )
            // Create GEP instruction to get the address of the field via pointer
            let gep = self.builder.createGEP(expr_value, struct_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // struct base
              self.global_ctx.llvm_ctx.getConstInt32(field_idx), // field index
            ])
            expr_type = field_type
            expr_value = gep // Return address, not loaded value
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Arrow access only supported on pointer to struct types, got \{expr_type}",
            )
        }
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
          // Check global variable environment
          match self.global_ctx.global_var_env.get(name) {
            Some((global_var, global_type)) =>
              // For global variables, return the global variable as lvalue (it's already an address)
              (global_type, global_var)
            None =>
              raise CodeGenError::UnSupportFeature(
                "Undefined variable: \{name}",
              )
          }
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
    GCCExtBlock(_) =>
      raise CodeGenError::UnSupportFeature(
        "GCC extension blocks cannot be lvalues",
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
  // Create basic blocks for the while loop with unique names
  let block_id = self.get_next_block_id()
  let cond_bb = self.func_value.addBasicBlock(name="while.cond.\{block_id}")
  let body_bb = self.func_value.addBasicBlock(name="while.body.\{block_id}")
  let exit_bb = self.func_value.addBasicBlock(name="while.exit.\{block_id}")

  // Jump to condition block
  ignore(self.builder.createBr(cond_bb))

  // Emit condition block
  self.builder.setInsertPoint(cond_bb)
  let (cond_type, cond_val) = self.emit_expr(cond)

  // Convert condition to boolean if needed
  let bool_cond = if cond_type != Int(1) && cond_type != UInt(1) {
    match cond_type {
      Ptr(_) => {
        // For pointers, convert to integer first, then compare with zero
        let ptr_as_int = self.builder.createPtrToInt(
          cond_val,
          self.global_ctx.llvm_ctx.getInt64Ty(),
        )
        let zero = self.global_ctx.llvm_ctx.getConstInt64(0)
        self.builder.createICmpNE(ptr_as_int, zero)
      }
      Int(_) | UInt(_) => {
        // For integers, compare with zero
        let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
        self.builder.createICmpNE(cond_val, zero)
      }
      FP(_) => {
        // For floating point, compare with zero
        let zero = self.global_ctx.llvm_ctx.getConstDouble(0.0)
        self.builder.createFCmpONE(cond_val, zero)
      }
      _ => {
        // Default: treat as integer
        let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
        self.builder.createICmpNE(cond_val, zero)
      }
    }
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

  // Only set exit block if it has predecessors (i.e., if there are break statements or fall-through)
  // In this case since all cases have return statements, the exit block is not needed
  // But we keep it for consistency and in case of fall-through cases
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

  // Create basic blocks for the for loop with unique names
  let block_id = self.get_next_block_id()
  let cond_bb = self.func_value.addBasicBlock(name="for.cond.\{block_id}")
  let body_bb = self.func_value.addBasicBlock(name="for.body.\{block_id}")
  let inc_bb = self.func_value.addBasicBlock(name="for.inc.\{block_id}")
  let exit_bb = self.func_value.addBasicBlock(name="for.exit.\{block_id}")

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

      // Generate unique names for basic blocks
      let block_id = self.get_next_block_id()
      let then_bb = self.func_value.addBasicBlock(name="if.then.\{block_id}")
      let else_bb = self.func_value.addBasicBlock(name="if.else.\{block_id}")
      let merge_bb = self.func_value.addBasicBlock(name="if.merge.\{block_id}")

      // Create conditional branch
      ignore(self.builder.createCondBr(bool_cond, then_bb, else_bb))

      // Emit then block
      self.builder.setInsertPoint(then_bb)
      let then_has_terminator = self.emit_statement_with_terminator_check(
        then_stmt,
      )
      if !then_has_terminator {
        ignore(self.builder.createBr(merge_bb))
      }

      // Emit else block
      self.builder.setInsertPoint(else_bb)
      let else_has_terminator = match else_stmt_opt {
        Some(else_stmt) => self.emit_statement_with_terminator_check(else_stmt)
        None => false
      }
      if !else_has_terminator {
        ignore(self.builder.createBr(merge_bb))
      }

      // Continue with merge block
      self.builder.setInsertPoint(merge_bb)
    }
    Switch(switch_expr, switch_stmt) =>
      self.emit_switch_statement(switch_expr, switch_stmt)
  }
}

///|
fn FuncCodeGenContext::emit_switch_statement(
  self : Self,
  switch_expr : Expr,
  switch_stmt : Statement,
) -> Unit raise {
  // Evaluate the switch expression (condition)
  let (cond_type, cond_val) = self.emit_expr(switch_expr)

  // Convert condition to integer if needed
  let switch_val = match cond_type {
    Int(_) => cond_val
    UInt(_) => cond_val
    _ => self.emit_cast(from_type=cond_type, to_type=Int(32), cond_val)
  }

  // Generate unique names for basic blocks
  let block_id = self.get_next_block_id()
  let default_bb = self.func_value.addBasicBlock(
    name="switch.default.\{block_id}",
  )
  let exit_bb = self.func_value.addBasicBlock(name="switch.exit.\{block_id}")

  // Create the switch instruction
  let switch_inst = self.builder.createSwitch(switch_val, default_bb)

  // Collect case information and create basic blocks for cases
  let case_blocks : Array[(Int, @IR.BasicBlock)] = []
  let has_default = Ref::new(false)

  // Process the switch statement to find cases and default
  match switch_stmt {
    CompoundStatement(comp_stmt) => {
      // First pass: collect case information
      self.collect_switch_cases(comp_stmt, case_blocks, has_default, block_id)

      // Add cases to switch instruction
      for case_item in case_blocks {
        let (case_value, case_bb) = case_item
        let const_int = self.global_ctx.llvm_ctx.getConstInt32(case_value)
        ignore(switch_inst.addCase(const_int, case_bb))
      }

      // Second pass: emit the switch body with proper control flow
      self.emit_switch_body(
        comp_stmt,
        case_blocks,
        default_bb,
        exit_bb,
        has_default.val,
      )
    }
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Switch statement body must be a compound statement",
      )
  }

  // Continue with exit block
  self.builder.setInsertPoint(exit_bb)
}

///|
fn FuncCodeGenContext::collect_switch_cases(
  self : Self,
  comp_stmt : CompoundStatement,
  case_blocks : Array[(Int, @IR.BasicBlock)],
  has_default : Ref[Bool],
  block_id : Int,
) -> Unit raise {
  for item in comp_stmt.items {
    match item {
      Statement(Statement::LabeledStatement(labeled_stmt)) =>
        match labeled_stmt {
          Case(const_expr, _) => {
            // Evaluate the case constant
            let (_, case_value) = self.emit_conditional_expr(const_expr)
            let case_bb = self.func_value.addBasicBlock(
              name="switch.case.\{case_value}.\{block_id}",
            )
            guard case_value.tryAsConst() is Some(case_value) else {
              raise CodeGenError::SyntaxError(
                "Case label must be a constant integer",
              )
            }
            guard case_value.asConstEnum() is ConstantInt(case_value) else {
              raise CodeGenError::SyntaxError(
                "Case label must be a constant integer",
              )
            }
            let case_value = case_value.to_int()
            case_blocks.push((case_value, case_bb))
          }
          Default(_) => has_default.val = true
          _ => () // Regular labels, skip
        }
      _ => () // Non-labeled statements, skip for now
    }
  }
}

///|
fn FuncCodeGenContext::emit_switch_body(
  self : Self,
  comp_stmt : CompoundStatement,
  case_blocks : Array[(Int, @IR.BasicBlock)],
  default_bb : @IR.BasicBlock,
  exit_bb : @IR.BasicBlock,
  has_default : Bool,
) -> Unit raise {
  // Create a map from case values to basic blocks
  let case_map = Map::new()
  for case_item in case_blocks {
    let (case_value, case_bb) = case_item
    case_map.set(case_value, case_bb)
  }

  // Process each statement in the compound statement
  // The key insight is that in C switch statements, each case/default label
  // starts a new basic block, and statements following a label are emitted
  // in that block until we hit another label or the end
  let mut current_bb : @IR.BasicBlock? = None
  for item in comp_stmt.items {
    match item {
      Statement(stmt) =>
        match stmt {
          LabeledStatement(labeled_stmt) =>
            match labeled_stmt {
              Case(const_expr, case_stmt) => {
                // Switch to the appropriate case block
                //let case_value = self.evaluate_case_constant(const_expr)
                let (_, case_value) = self.emit_conditional_expr(const_expr)
                guard case_value.tryAsConst() is Some(case_value) else {
                  raise CodeGenError::SyntaxError(
                    "Case label must be a constant integer",
                  )
                }
                guard case_value.asConstEnum() is ConstantInt(case_value) else {
                  raise CodeGenError::SyntaxError(
                    "Case label must be a constant integer",
                  )
                }
                let case_value = case_value.to_int()
                let case_bb = case_map.get(case_value).unwrap()
                self.builder.setInsertPoint(case_bb)
                current_bb = Some(case_bb)

                // Emit the case statement (this might be a return, break, or other statement)
                self.emit_statement(case_stmt)
              }
              Default(default_stmt) => {
                // Switch to the default block
                self.builder.setInsertPoint(default_bb)
                current_bb = Some(default_bb)

                // Emit the default statement
                self.emit_statement(default_stmt)
              }
              _ =>
                // Regular labels not supported in switch for now
                raise CodeGenError::UnSupportFeature(
                  "Regular labels not supported in switch statements",
                )
            }
          _ =>
            // Regular statement - emit in current case block
            if current_bb is Some(_) {
              self.emit_statement(stmt)
            } else {
              // Statements that appear before any case/default are ignored
              // This is consistent with C behavior
              ()
            }
        }
      Declaration(decl) =>
        // Declarations in switch - emit in current case block
        if current_bb is Some(_) {
          self.emit_declaration(decl)
        } else {
          // Declarations that appear before any case/default are ignored
          ()
        }
    }
  }

  // If default block was not used, make it jump to exit
  if !has_default {
    self.builder.setInsertPoint(default_bb)
    ignore(self.builder.createBr(exit_bb))
  }

  // Ensure the exit block has a terminator instruction
  // Always add a return to the exit block since it might be reached by break statements
  self.builder.setInsertPoint(exit_bb)
  match self.return_type {
    Void => ignore(self.builder.createRetVoid())
    _ => {
      // Create a dummy return value for non-void functions
      let zero = self.global_ctx.llvm_ctx.getConstInt32(0)
      let return_val = self.emit_cast(
        from_type=Int(32),
        to_type=self.return_type,
        zero,
      )
      ignore(self.builder.createRet(return_val))
    }
  }
}

///|
fn FuncCodeGenContext::emit_labeled_statement(
  self : Self,
  labeled_stmt : LabeledStatement,
) -> Unit raise {
  match labeled_stmt {
    Case(_, stmt) =>
      // For case statements, the block switching is handled by emit_switch_body
      // Here we just emit the statement content
      self.emit_statement(stmt)
    Default(stmt) =>
      // For default statements, the block switching is handled by emit_switch_body
      // Here we just emit the statement content  
      self.emit_statement(stmt)
    Label(label_name, stmt) =>
      // Regular labels - for now, just emit the statement
      // TODO: Implement proper label/goto support
      self.emit_statement(stmt)
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
    Some(pointer) => {
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        result_type = Ptr(result_type)
      }
    }
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
fn FuncCodeGenContext::evaluate_constant_expr(
  self : Self,
  assign_expr : AssignExpr,
) -> Int raise CodeGenError {
  self.global_ctx.evaluate_constant_expr(assign_expr)
}

///|
fn CodeGenContext::evaluate_constant_expr(
  self : Self,
  assign_expr : AssignExpr,
) -> Int raise CodeGenError {
  // Simple constant expression evaluator for array sizes
  // impl of evaluate_constant_conditional is in `constant.mbt`
  match assign_expr {
    Conditional(cond_expr) => self.evaluate_constant_conditional(cond_expr)
    _ =>
      raise CodeGenError::UnSupportFeature(
        "Only simple constant expressions supported for array sizes",
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
fn FuncCodeGenContext::count_initializer_elements(
  self : Self,
  initializer : Initializer,
) -> Int {
  ignore(self)
  match initializer {
    AssignExpr(_) => 1
    InitList(init_pairs) => init_pairs.length()
  }
}

///|
fn FuncCodeGenContext::analysis_declarator_type_with_initializer(
  self : Self,
  declarator : Declarator,
  base_type : Type,
  initializer : Initializer?,
) -> Type raise CodeGenError {
  let mut result_type = base_type

  // Handle pointer in declarator
  match declarator.pointer {
    Some(pointer) => {
      let pointer_levels = pointer.inner()
      for _ in pointer_levels {
        result_type = Ptr(result_type)
      }
    }
    None => ()
  }

  // Handle direct declarator with potential size inference
  result_type = self.analysis_direct_declarator_type_with_initializer(
    declarator.directDeclarator,
    result_type,
    initializer,
  )
  result_type
}

///|
fn FuncCodeGenContext::analysis_direct_declarator_type_with_initializer(
  self : Self,
  direct_declarator : DirectDeclarator,
  base_type : Type,
  initializer : Initializer?,
) -> Type raise CodeGenError {
  // Helper function to collect dimensions and handle proper ordering
  self.build_array_type_recursive(direct_declarator, base_type, initializer)
}

///|
fn FuncCodeGenContext::build_array_type_recursive(
  self : Self,
  direct_declarator : DirectDeclarator,
  base_type : Type,
  initializer : Initializer?,
) -> Type raise CodeGenError {
  match direct_declarator {
    Array(_, _, _) => {
      // Collect all array dimensions in a list
      let dimensions : Array[Int] = []
      let mut current_declarator = direct_declarator
      let mut remaining_initializer = initializer

      // Extract all array dimensions from nested AST
      while true {
        match current_declarator {
          Identifier(_) => break
          Array(inner_declarator, _, size_expr) => {
            let dimension_size = match size_expr {
              Some(assign_expr) =>
                // Evaluate constant array size expression
                self.evaluate_constant_expr(assign_expr)
              None =>
                // Infer size from initializer if available
                match remaining_initializer {
                  Some(init) => {
                    let size = self.count_initializer_elements(init)
                    remaining_initializer = None // Mark initializer as used
                    size
                  }
                  None =>
                    raise CodeGenError::UnSupportFeature(
                      "Array declaration without size and without initializer",
                    )
                }
            }
            dimensions.push(dimension_size)
            current_declarator = inner_declarator
          }
          _ =>
            raise CodeGenError::UnSupportFeature(
              "Complex declarators not yet supported",
            )
        }
      }

      // Now build the type with dimensions in reverse order
      // dimensions[0] is the rightmost dimension in C syntax (should be innermost in type)  
      // dimensions[n-1] is the leftmost dimension in C syntax (should be outermost in type)
      let mut result_type = base_type
      for i = 0; i < dimensions.length(); i = i + 1 {
        let size = dimensions[i]
        result_type = Array(result_type, size)
      }

      // Special handling for string arrays: convert char[][] to char*[]
      // This is a temporary fix to make string literals work
      match result_type {
        Array(Array(Int(8), _), outer_size) =>
          // This is a 2D char array, likely for strings
          // Convert to array of char pointers for easier handling
          Array(Ptr(Int(8)), outer_size)
        _ => result_type
      }
    }
    StaticArray(inner_declarator, _type_quals, _size_expr) => {
      // Handle static array declarator
      let element_type = self.analysis_direct_declarator_type_with_initializer(
        inner_declarator,
        base_type,
        None,
      )
      // TODO: Implement proper static array handling
      Array(element_type, 1) // Placeholder
    }
    Parenthesized(inner_declarator) =>
      // Handle parenthesized declarator
      self.analysis_declarator_type_with_initializer(
        inner_declarator, base_type, initializer,
      )
    Identifier(_) => base_type
    _ =>
      raise CodeGenError::UnSupportFeature("Unsupported direct declarator type")
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

    // Analyze the declarator to get the final type, considering initializer for array size inference
    let var_type = self.analysis_declarator_type_with_initializer(
      declarator, base_type, initializer,
    )

    // Allocate space for the variable
    let (llvm_type, env_type, alloca, is_array) = match var_type {
      Array(elem_type, size) => {
        // For array variables, allocate the array and store the pointer type in environment
        let array_llvm_type = self.global_ctx.convert_type_to_llvm(var_type)
        let array_alloca = self.builder.createAlloca(
          array_llvm_type,
          name=var_name,
        )

        // Array variable: store the original array type in environment
        // This is important for proper lvalue handling of array indexing
        (array_llvm_type, var_type, array_alloca, true)
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
      Some(init) => self.emit_init_declarator(init, var_type, alloca)
      // No initialization - variable is uninitialized
      None => ()
    }
  }
}

///|
fn FuncCodeGenContext::emit_init_declarator(
  self : Self,
  init : Initializer,
  var_type : Type,
  alloca : &LLVMValue,
) -> Unit raise {
  match init {
    AssignExpr(assign_expr) => {
      let (init_type, init_val) = self.emit_assign_expr(assign_expr)
      let init_val = if init_type != var_type {
        self.emit_cast(from_type=init_type, to_type=var_type, init_val)
      } else {
        init_val
      }
      let _ = self.builder.createStore(init_val, alloca)

    }
    InitList(init_pairs) =>
      // Handle array and struct initialization lists
      match var_type {
        Array(elem_type, size) => {
          // Initialize array elements one by one
          let elem_llvm_type = self.global_ctx.convert_type_to_llvm(elem_type)
          let mut index = 0
          for pair in init_pairs {
            let (designators, initializer) = pair
            // For simple array initialization, ignore designators for now
            if index >= size {
              break // Don't initialize beyond array bounds
            }

            // Handle different types of initializers
            match initializer {
              AssignExpr(assign_expr) => {
                // Simple scalar initialization
                let (init_type, init_val) = self.emit_assign_expr(assign_expr)
                let init_val = if init_type != elem_type {
                  self.emit_cast(
                    from_type=init_type,
                    to_type=elem_type,
                    init_val,
                  )
                } else {
                  init_val
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
              }
              InitList(nested_init_pairs) =>
                // Handle nested initialization for multi-dimensional arrays and struct arrays
                match elem_type {
                  Array(inner_elem_type, inner_size) => {
                    // This is a nested array (e.g., 2D array element)
                    let mut inner_index = 0
                    for nested_pair in nested_init_pairs {
                      let (_, nested_initializer) = nested_pair
                      if inner_index >= inner_size {
                        break // Don't initialize beyond array bounds
                      }

                      // Get the nested value
                      let nested_init_val = match nested_initializer {
                        AssignExpr(assign_expr) => {
                          let (init_type, init_val) = self.emit_assign_expr(
                            assign_expr,
                          )
                          if init_type != inner_elem_type {
                            self.emit_cast(
                              from_type=init_type,
                              to_type=inner_elem_type,
                              init_val,
                            )
                          } else {
                            init_val
                          }
                        }
                        InitList(_) =>
                          raise CodeGenError::UnSupportFeature(
                            "Deeply nested InitList (3D+) not supported yet",
                          )
                      }

                      // Calculate the GEP to the nested array element: arr[index][inner_index]
                      let index_val = self.global_ctx.llvm_ctx.getConstInt32(
                        index,
                      )
                      let inner_index_val = self.global_ctx.llvm_ctx.getConstInt32(
                        inner_index,
                      )
                      let array_llvm_type = self.global_ctx.convert_type_to_llvm(
                        var_type,
                      )
                      let gep = self.builder.createGEP(
                        alloca,
                        array_llvm_type,
                        [
                          self.global_ctx.llvm_ctx.getConstInt32(0), // Array base
                          index_val, // First dimension index
                          inner_index_val, // Second dimension index
                        ],
                      )

                      // Store the nested value
                      ignore(self.builder.createStore(nested_init_val, gep))
                      inner_index = inner_index + 1
                    }
                  }
                  Struct(struct_name, struct_field_types) => {
                    // This is a struct array element: arr[index] = { .field1 = value1, .field2 = value2 }
                    let struct_llvm_type = self.global_ctx.convert_type_to_llvm(
                      elem_type,
                    )
                    let array_llvm_type = self.global_ctx.convert_type_to_llvm(
                      var_type,
                    )

                    // Calculate GEP to the struct element in the array: &arr[index]
                    let index_val = self.global_ctx.llvm_ctx.getConstInt32(
                      index,
                    )
                    let struct_gep = self.builder.createGEP(
                      alloca,
                      array_llvm_type,
                      [
                        self.global_ctx.llvm_ctx.getConstInt32(0), // Array base
                        index_val,
                      ], // Index into array
                    )

                    // Initialize each field of the struct
                    for nested_idx, nested_pair in nested_init_pairs.iter2() {
                      let (designators, nested_initializer) = nested_pair

                      // Determine field name and index based on designators
                      let (field_name, field_idx) = if designators.length() == 0 {
                        // Simple initialization like { 3.0, 4.0 } - use field order
                        if nested_idx >= struct_field_types.length() {
                          raise CodeGenError::SyntaxError(
                            "Too many initializers for struct \{struct_name}",
                          )
                        }
                        let (field_name, _) = struct_field_types[nested_idx]
                        (field_name, nested_idx)
                      } else if designators.length() == 1 {
                        // Designated initialization like { .x = 3, .y = 4 }
                        let field_name = match designators[0] {
                          DotAccess(name) => name
                          _ =>
                            raise CodeGenError::UnSupportFeature(
                              "Only dot access designators supported for struct initialization",
                            )
                        }
                        // Find the field index and type
                        let field_idx = struct_field_types.search_by(pair => pair.0 ==
                          field_name)
                        let field_idx = match field_idx {
                          Some(idx) => idx
                          None =>
                            raise CodeGenError::SyntaxError(
                              "Field \{field_name} not found in struct \{struct_name}",
                            )
                        }
                        (field_name, field_idx)
                      } else {
                        raise CodeGenError::UnSupportFeature(
                          "Multiple designators not supported yet",
                        )
                      }
                      let (_, field_type) = struct_field_types[field_idx]

                      // Get the field value
                      let field_init_val = match nested_initializer {
                        AssignExpr(assign_expr) => {
                          let (init_type, init_val) = self.emit_assign_expr(
                            assign_expr,
                          )
                          if init_type != field_type {
                            self.emit_cast(
                              from_type=init_type,
                              to_type=field_type,
                              init_val,
                            )
                          } else {
                            init_val
                          }
                        }
                        InitList(_) =>
                          raise CodeGenError::UnSupportFeature(
                            "Nested struct field initialization not supported yet",
                          )
                      }

                      // Create GEP to access the field: &arr[index].field
                      let field_gep = self.builder.createGEP(
                        struct_gep,
                        struct_llvm_type,
                        [
                          self.global_ctx.llvm_ctx.getConstInt32(0), // struct base
                          self.global_ctx.llvm_ctx.getConstInt32(field_idx), // field index
                        ],
                      )

                      // Store the field value
                      ignore(
                        self.builder.createStore(field_init_val, field_gep),
                      )
                    }
                  }
                  _ =>
                    raise CodeGenError::UnSupportFeature(
                      "Nested InitList only supported for multi-dimensional arrays and struct arrays",
                    )
                }
            }
            index = index + 1
          }
        }
        Struct(struct_name, field_types) => {
          // Handle struct initialization lists like { .x = 3, .y = 4 } or { 3, 4 }
          let struct_llvm_type = self.global_ctx.convert_type_to_llvm(var_type)
          for i, pair in init_pairs.iter2() {
            let (designators, initializer) = pair

            // Determine field name and index based on designators
            let (field_name, field_idx) = if designators.length() == 0 {
              // Simple initialization like { 3.0, 4.0 } - use field order
              if i >= field_types.length() {
                raise CodeGenError::SyntaxError(
                  "Too many initializers for struct \{struct_name}",
                )
              }
              let (field_name, _) = field_types[i]
              (field_name, i)
            } else if designators.length() == 1 {
              // Designated initialization like { .x = 3, .y = 4 }
              let field_name = match designators[0] {
                DotAccess(name) => name
                _ =>
                  raise CodeGenError::UnSupportFeature(
                    "Only dot access designators supported for struct initialization",
                  )
              }
              // Find the field index and type
              let field_idx = field_types.search_by(pair => pair.0 == field_name)
              let field_idx = match field_idx {
                Some(idx) => idx
                None =>
                  raise CodeGenError::SyntaxError(
                    "Field \{field_name} not found in struct \{struct_name}",
                  )
              }
              (field_name, field_idx)
            } else {
              raise CodeGenError::UnSupportFeature(
                "Multiple designators not supported yet",
              )
            }
            let (_, field_type) = field_types[field_idx]

            // Get the initialization value
            let init_val = match initializer {
              AssignExpr(assign_expr) => {
                let (init_type, init_val) = self.emit_assign_expr(assign_expr)
                if init_type != field_type {
                  self.emit_cast(
                    from_type=init_type,
                    to_type=field_type,
                    init_val,
                  )
                } else {
                  init_val
                }
              }
              InitList(_) =>
                raise CodeGenError::UnSupportFeature(
                  "Nested struct initialization not supported yet",
                )
            }

            // Create GEP to access the field
            let gep = self.builder.createGEP(alloca, struct_llvm_type, [
              self.global_ctx.llvm_ctx.getConstInt32(0), // struct base
              self.global_ctx.llvm_ctx.getConstInt32(field_idx), // field index
            ])

            // Store the value in the field
            ignore(self.builder.createStore(init_val, gep))
          }
        }
        _ =>
          raise CodeGenError::UnSupportFeature(
            "InitList only supported for array and struct types currently",
          )
      }
  }
}
