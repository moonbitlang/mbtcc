traitalias @IR.Type as LLVMType
traitalias @IR.Value as LLVMValue

pub enum Type {
  Void
  Int(Int)  // Bitwidth, 1, 8, 16, 32, 64
  UInt(Int)
  FP(Int)   // Bitwidth, 32, 64
  Ptr(Type)
  Struct(Array[Type])
  Union(Array[Type])
  Enum(Array[(String, Int64)])
} derive(Show, Eq)

fn CodeGenContext::convert_type_to_llvm(self: Self, ty: Type) -> &LLVMType {
  ...
}

pub suberror CodeGenError {
  UnSupportFeature(String)
  LLVMError(Error)
} derive(Show)

pub struct CodeGenContext {
  external_decls : Array[ExternalDeclaration]
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
}

pub fn CodeGenContext::dump(self: Self) -> Unit {
  self.llvm_mod.dump()
}

pub fn CodeGenContext::from_parser(ctx: ParserContext) -> CodeGenContext {
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule("demo")
  CodeGenContext::{ external_decls: ctx.external_decls, llvm_ctx, llvm_mod }
}

pub fn CodeGenContext::analysis_declspecs(self: Self, declspecs: Array[DeclSpec]) -> Type {
  ...
}

pub fn CodeGenContext::run(self: Self) -> Unit raise {
  for decl in self.external_decls {
    self.emit_external_decl(decl)
  }
}

pub fn CodeGenContext::emit_external_decl(self: Self, decl: ExternalDeclaration) -> Unit raise {
  match decl {
    FunctionDefinition(func_def) => self.emit_function_definition(func_def)
    Declaration(decl) => self.emit_declaration(decl)
  }
}

fn CodeGenContext::analysis_param_declarator(
  self: Self, decl: Declarator, basic_type: Type
) -> (Type, String) raise CodeGenError {
  ...
}

fn CodeGenContext::analysis_typename(self: Self, type_name: TypeName) -> Type raise CodeGenError {
  ...
}

pub fn CodeGenContext::emit_declaration(self: Self, decl: Declaration) -> Unit {
  ...
}

pub fn CodeGenContext::emit_cast(self: Self, from_type~: Type, to_type~: Type, value: &LLVMValue) -> &LLVMValue raise {
  ...
}

struct FuncCodeGenContext {
  global_ctx: CodeGenContext
  func_def : FunctionDefinition
  func_value : @IR.Function
  var_env : Env[&LLVMValue]
  builder: @IR.IRBuilder
}

pub fn CodeGenContext::emit_function_definition(self: Self, func_def: FunctionDefinition) -> Unit raise {
  if !func_def.kr_declarations.is_empty() {
    raise CodeGenError::UnSupportFeature("K&R style function definitions are not supported.")
  }
  let basic_type = self.analysis_declspecs(func_def.declSpecs)
  let (ret_type, func_name, params) = self.analysis_func_declarator(func_def.declarator, basic_type)
  let param_types: Array[&LLVMType] = Array::new()
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
  let var_env : Env[&LLVMValue] = Env::new()
  for i in 0 ..< params.length() {
    let (param_name, _) = params[i]
    let llvm_param = llvm_func.getArg(i).unwrap()
    var_env.set(param_name, llvm_param)
  }
  let builder = self.llvm_ctx.createBuilder()
  let func_codegen = FuncCodeGenContext::{ global_ctx: self, func_def, func_value: llvm_func, var_env, builder }
  func_codegen.emit_function_body()
}

fn CodeGenContext::analysis_func_declarator(
  self: Self, decl: Declarator, basic_type: Type
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
        raise CodeGenError::UnSupportFeature("Variadic functions are not supported.")
      }
      for param in params {
        let {decl_specs, declarator } = param
        guard declarator is Some(declarator) else {
          raise CodeGenError::UnSupportFeature("Parameter without declarator is not supported.")
        }
        guard declarator is Declarator(declarator) else {
          raise CodeGenError::UnSupportFeature("Only simple parameter declarators are supported.")
        }
        let param_type = self.analysis_declspecs(decl_specs)
        let (param_type, param_name) = self.analysis_param_declarator(declarator, param_type)
        func_params.push((param_name, param_type))
      }
      (func_name, func_params)
    }
    _ => raise UnSupportFeature("Only function declarators are supported.")
  }
  (ret_type, func_name, params)
}

fn FuncCodeGenContext::emit_function_body(self: Self) -> Unit raise {
  let compound_statement = self.func_def.body
  let entry_bb = self.func_value.addBasicBlock(name="entry")
  self.builder.setInsertPoint(entry_bb)
  self.emit_compound_statement(compound_statement)
}

fn FuncCodeGenContext::emit_compound_statement(self: Self, comp_stmt: CompoundStatement) -> Unit raise {
  let { items } = comp_stmt
  for item in items {
    match item {
      Statement(stmt) => self.emit_statement(stmt)
      Declaration(decl) => self.emit_declaration(decl)
    }
  }
}

fn FuncCodeGenContext::emit_statement(self: Self, stmt: Statement) -> Unit raise {
  match stmt {
    Empty => ()
    LabeledStatement(label) => { ... }
    ExpressionStatement(expr) => self.emit_expr_stat(expr)
    SelectionStatement(sel_stmt) => { ... }
    IterationStatement(iter_stmt) => self.emit_iteration_statement(iter_stmt)
    JumpStatement(jump_stmt) => { ... }
    CompoundStatement(comp_stmt) => self.emit_compound_statement(comp_stmt)
  }
}

fn FuncCodeGenContext::emit_expr(self: Self, expr: Expr) -> (Type, &LLVMValue) raise {
  let { exprs } = expr
  let first_assign_expr = exprs[0]
  let (ty, val) = self.emit_assign_expr(first_assign_expr)
  for i in 1..<exprs.length() {
    let assign_expr = exprs[i]
    let _ = self.emit_assign_expr(assign_expr)
  }
  (ty, val)
}

fn FuncCodeGenContext::emit_expr_stat(self: Self, expr_stmt: Expr) -> Unit raise {
  let { exprs } = expr_stmt
  for assign_expr in exprs {
    let _ = self.emit_assign_expr(assign_expr)
  }
}

fn FuncCodeGenContext::emit_assign_expr(self: Self, assign_expr: AssignExpr) -> (Type, &LLVMValue) raise {
  match assign_expr {
    Conditional(cond) => self.emit_conditional_expr(cond)
    Assign(left, op, expr) => {
      let (lty, left) = self.emit_unary_expr_as_lvalue(left)
      let (rty, right) = self.emit_assign_expr(expr)
      let left_type = self.global_ctx.convert_type_to_llvm(lty)
      let left_val = self.builder.createLoad(left_type, left)
      let right = if lty != rty {
        self.global_ctx.emit_cast(from_type=rty, to_type=lty, right) catch {
          err => raise CodeGenError::LLVMError(err)
        }
      } else {
        right
      }
      let val = match op {
        Assign => {
          self.builder.createStore(right, left)
        }
        AddAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createAdd(left_val, right)
            FP(_) => self.builder.createFAdd(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for AddAssign.")
          }
          self.builder.createStore(result, left)
        }
        SubAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createSub(left_val, right)
            FP(_) => self.builder.createFSub(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for SubAssign.")
          }
          self.builder.createStore(result, left)
        }
        MultAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createMul(left_val, right)
            FP(_) => self.builder.createFMul(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for MultAssign.")
          }
          self.builder.createStore(result, left)
        }
        DivAssign => {
          let result = match lty {
            Int(_) => self.builder.createSDiv(left_val, right)
            UInt(_) => self.builder.createUDiv(left_val, right)
            FP(_) => self.builder.createFDiv(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for DivAssign.")
          }
          self.builder.createStore(result, left)
        }
        ModAssign => {
          let result = match lty {
            Int(_) => self.builder.createSRem(left_val, right)
            UInt(_) => self.builder.createURem(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for ModAssign.")
          }
          self.builder.createStore(result, left)
        }
        AndAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createAnd(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for AndAssign.")
          }
          self.builder.createStore(result, left)
        }
        OrAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createOr(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for OrAssign.")
          }
          self.builder.createStore(result, left)
        }
        BitwiseAndAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createAnd(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for BitAndAssign.")
          }
          self.builder.createStore(result, left)
        }
        BitwiseOrAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createOr(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for BitOrAssign.")
          }
          self.builder.createStore(result, left)
        }
        BitwiseXorAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createXor(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for BitXorAssign.")
          }
          self.builder.createStore(result, left)
        }
        LeftShiftAssign => {
          let result = match lty {
            Int(_) | UInt(_) => self.builder.createShl(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for LeftShiftAssign.")
          }
          self.builder.createStore(result, left)
        }
        RightShiftAssign => {
          let result = match lty {
            Int(_) => self.builder.createAShr(left_val, right)
            UInt(_) => self.builder.createLShr(left_val, right)
            _ => raise CodeGenError::UnSupportFeature("Unsupported type for RightShiftAssign.")
          }
          self.builder.createStore(result, left)
        }
      }
      (lty, val)
    }
  }
}

fn FuncCodeGenContext::emit_conditional_expr(self: Self, cond_expr: ConditionalExpr) -> (Type, &LLVMValue) raise {
  let { expr, select } = cond_expr

  let (cond_type, cond_val) = self.emit_logical_or_expr(expr)
  if select is Some(select) {
    let cond_val = if not(cond_type is Int(1) || cond_type is UInt(1)) {
      self.global_ctx.emit_cast(from_type=cond_type, to_type=Int(1), cond_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      cond_val
    }
    let (then_expr, else_expr) = select
    let (then_ty, then_val) = self.emit_expr(then_expr)
    let (else_ty, else_val) = self.emit_conditional_expr(else_expr)
    let then_val = if then_ty != else_ty {
      self.global_ctx.emit_cast(from_type=then_ty, to_type=else_ty, then_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      then_val
    }
    let val = self.builder.createSelect(cond_val, then_val, else_val)
    (else_ty, val)
  } else {
    (cond_type, cond_val)
  }
}

fn FuncCodeGenContext::emit_logical_or_expr(self: Self, log_or_expr: LogicalOrExpr) -> (Type, &LLVMValue) raise {
  let { exprs: logical_and_exprs } = log_or_expr
  let (first_ty, first_val) = self.emit_logical_and_expr(logical_and_exprs[0])
  for i in 1 ..< (logical_and_exprs.length()) {
    let (ty, val) = self.emit_logical_and_expr(logical_and_exprs[i])
    let first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_logical_and_expr(self: Self, log_and_expr: LogicalAndExpr) -> (Type, &LLVMValue) raise {
  let { exprs: inclusive_or_exprs } = log_and_expr
  let (first_ty, first_val) = self.emit_inclusive_or_expr(inclusive_or_exprs[0])
  for i in 1 ..< (inclusive_or_exprs.length()) {
    let (ty, val) = self.emit_inclusive_or_expr(inclusive_or_exprs[i])
    let first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_inclusive_or_expr(self: Self, incl_or_expr: InclusiveOrExpr) -> (Type, &LLVMValue) raise {
  let { exprs: exclusive_or_exprs } = incl_or_expr
  let (first_ty, first_val) = self.emit_exclusive_or_expr(exclusive_or_exprs[0])
  for i in 1 ..< (exclusive_or_exprs.length()) {
    let (ty, val) = self.emit_exclusive_or_expr(exclusive_or_exprs[i])
    let first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_exclusive_or_expr(self: Self, excl_or_expr: ExclusiveOrExpr) -> (Type, &LLVMValue) raise {
  let { exprs: and_exprs } = excl_or_expr
  let (first_ty, first_val) = self.emit_and_expr(and_exprs[0])
  for i in 1 ..< (and_exprs.length()) {
    let (ty, val) = self.emit_and_expr(and_exprs[i])
    let first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_and_expr(self: Self, and_expr: AndExpr) -> (Type, &LLVMValue) raise {
  let { exprs: equality_exprs } = and_expr
  let (first_ty, first_val) = self.emit_equality_expr(equality_exprs[0])
  for i in 1 ..< (equality_exprs.length()) {
    let (ty, val) = self.emit_equality_expr(equality_exprs[i])
    let first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_equality_expr(self: Self, eq_expr: EqualityExpr) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = eq_expr
  let (first_ty, first_val) = self.emit_relational_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1 ..< (exprs.length()) {
    let (ty, val) = self.emit_relational_expr(exprs[i])
    first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
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

fn FuncCodeGenContext::emit_relational_expr(self: Self, rel_expr: RelationalExpr) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = rel_expr
  let (first_ty, first_val) = self.emit_shift_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1 ..< (exprs.length()) {
    let (ty, val) = self.emit_shift_expr(exprs[i])
    first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
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

fn FuncCodeGenContext::emit_shift_expr(self: Self, shift_expr: ShiftExpr) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = shift_expr
  let (first_ty, first_val) = self.emit_addsub_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1 ..< (exprs.length()) {
    let (ty, val) = self.emit_addsub_expr(exprs[i])
    first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
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

fn FuncCodeGenContext::emit_addsub_expr(self: Self, add_expr: AddSubExpr) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = add_expr
  let (first_ty, first_val) = self.emit_mult_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1 ..< (exprs.length()) {
    let (ty, val) = self.emit_mult_expr(exprs[i])
    first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      Add => match first_ty {
        Int(_) | UInt(_) => self.builder.createAdd(first_val, val)
        FP(_) => self.builder.createFAdd(first_val, val)
        _ => raise CodeGenError::UnSupportFeature("Unsupported type for Plus operation.")
      }
      Sub => match first_ty {
        Int(_) | UInt(_) => self.builder.createSub(first_val, val)
        FP(_) => self.builder.createFSub(first_val, val)
        _ => raise CodeGenError::UnSupportFeature("Unsupported type for Minus operation.")
      }
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_mult_expr(self: Self, mult_expr: MultExpr) -> (Type, &LLVMValue) raise {
  let { exprs, ops } = mult_expr
  let (first_ty, first_val) = self.emit_cast_expr(exprs[0])
  let mut first_ty = first_ty
  let mut first_val = first_val
  for i in 1 ..< (exprs.length()) {
    let (ty, val) = self.emit_cast_expr(exprs[i])
    first_val = if first_ty != ty {
      self.global_ctx.emit_cast(from_type=first_ty, to_type=ty, first_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
    } else {
      first_val
    }
    let op = ops[i - 1]
    let result = match op {
      Mult => match first_ty {
        Int(_) | UInt(_) => self.builder.createMul(first_val, val)
        FP(_) => self.builder.createFMul(first_val, val)
        _ => raise CodeGenError::UnSupportFeature("Unsupported type for Multiplication operation.")
      }
      Div => match first_ty {
        Int(_) => self.builder.createSDiv(first_val, val)
        UInt(_) => self.builder.createUDiv(first_val, val)
        FP(_) => self.builder.createFDiv(first_val, val)
        _ => raise CodeGenError::UnSupportFeature("Unsupported type for Division operation.")
      }
      Mod => match first_ty {
        Int(_) => self.builder.createSRem(first_val, val)
        UInt(_) => self.builder.createURem(first_val, val)
        _ => raise CodeGenError::UnSupportFeature("Unsupported type for Modulus operation.")
      }
    }
    first_val = result
    first_ty = ty
  }
  (first_ty, first_val)
}

fn FuncCodeGenContext::emit_cast_expr(self: Self, cast_expr: CastExpr) -> (Type, &LLVMValue) raise {
  match cast_expr {
    UnaryExpr(unary_expr) => self.emit_unary_expr(unary_expr)
    Cast(type_name, expr) => {
      let ty = self.global_ctx.analysis_typename(type_name)
      let (expr_type, expr_val) = self.emit_cast_expr(expr)
      let casted_val = self.global_ctx.emit_cast(from_type=expr_type, to_type=ty, expr_val) catch {
        err => raise CodeGenError::LLVMError(err)
      }
      (ty, casted_val)
    }
  }
}

fn FuncCodeGenContext::emit_unary_expr(self: Self, unary_expr: UnaryExpr) -> (Type, &LLVMValue) raise {
  ...
}

fn FuncCodeGenContext::emit_postfix_expr(self: Self, post_expr: PostFixExpr) -> (Type, &LLVMValue) raise {
  ...
}

fn FuncCodeGenContext::emit_prim_expr(self: Self, prim_expr: PrimExpr) -> (Type, &LLVMValue) raise {
  ...
}

fn FuncCodeGenContext::emit_unary_expr_as_lvalue(self: Self, unary_expr: UnaryExpr) -> (Type, &LLVMValue) raise {
  ...
}

fn FuncCodeGenContext::emit_postfix_expr_as_lvalue(self: Self, post_expr: PostFixExpr) -> (Type, &LLVMValue) raise {
  ...
}

fn FuncCodeGenContext::emit_prim_expr_as_lvalue(self: Self, prim_expr: PrimExpr) -> (Type, &LLVMValue) raise {
  ...
}

fn FuncCodeGenContext::emit_iteration_statement(self: Self, iter_stmt: IterationStatement) -> Unit raise {
  match iter_stmt {
    While(cond, stmt) => {...}
    DoWhile(stmt, cond_expr) => {...}
    For(for_cond, stmt) => {...}
  }
}

fn FuncCodeGenContext::emit_while(self: Self, cond: Expr, stmt: Statement) -> Unit raise {
  ...
}

fn FuncCodeGenContext::emit_do_while(self: Self, stmt: Statement, cond_expr: Expr) -> Unit raise {
  ...
}

fn FuncCodeGenContext::emit_for(self: Self, for_cond: ForCondition, stmt: Statement) -> Unit raise {
  ...
}

fn FuncCodeGenContext::emit_declaration(self: Self, decl: Declaration) -> Unit raise {
  match decl {
    Decl(declspecs, inits) => self.emit_decl(declspecs, inits)
  }
}

fn FuncCodeGenContext::emit_decl(self: Self, declspecs: Array[DeclSpec], inits: Array[InitDeclarator]) -> Unit raise {
  ...
}
