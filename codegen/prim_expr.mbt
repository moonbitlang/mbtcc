///|
fn Context::emit_prim_expr(
  self : Context,
  expr : @parser.PrimExpr,
) -> &@IR.Value raise {
  let { llvm_ctx, .. } = self
  match expr.kind {
    Ident(name) => self.get_value_by_name(name)
    Char(c) => llvm_ctx.getConstInt8(c.to_int())
    Int(i) => llvm_ctx.getConstInt32(i)
    Long(i) => llvm_ctx.getConstInt64(i)
    LongLong(i) => llvm_ctx.getConstInt64(i)
    UInt(i) => llvm_ctx.getConstInt32(i.reinterpret_as_int())
    ULong(i) => llvm_ctx.getConstInt64(i.reinterpret_as_int64())
    ULongLong(i) => llvm_ctx.getConstInt64(i.reinterpret_as_int64())
    Float(f) => llvm_ctx.getConstFloat(f)
    Double(f) => llvm_ctx.getConstDouble(f)
    Strings(strs) => {
      let full_str = strs.join("")
      self.builder.createGlobalString(full_str)
    }
    Paren(expr) => self.emit_expr(expr)
    StmtExpr(comp) => self.emit_stmt_expr(comp)
  }
}

///|
// GNU statement expression: `({ ... })`
// Evaluate the compound statement in an inner scope and return the value of the
// last expression-statement.
fn Context::emit_stmt_expr(
  self : Context,
  comp : @parser.CompoundStmt,
) -> &@IR.Value raise {
  let { items, .. } = comp
  let _ = self.enter_scope()
  let mut last_val : &@IR.Value = self.llvm_ctx.getConstInt32(0)
  let mut has_last = false
  for i, item in items {
    match item {
      Right(decl) => self.emit_local_decl(decl)
      Left(stmt) =>
        match stmt.kind {
          Expr(e) if i == items.length() - 1 => {
            last_val = self.emit_expr(e)
            has_last = true
          }
          _ => self.emit_statement(stmt)
        }
    }
  }
  let _ = self.exit_scope()
  // Parser enforces the last item is an expression statement; keep a fallback.
  if has_last {
    last_val
  } else {
    self.llvm_ctx.getConstInt32(0)
  }
}

///|
fn Context::get_value_by_name(self : Self, name : String) -> &@IR.Value raise {
  match self.var_env.get(name) {
    Some(val) =>
      // Check if we have type information for this variable
      // If we do, it means it's a local variable that needs to be loaded
      match self.var_types.get(name) {
        Some(cty) =>
          match cty.dataKind {
            Array(_, _) => {
              let arr_llvm_ty = self.ctype_to_llvm_type(cty)
              let zero = self.llvm_ctx.getConstInt32(0)
              let indices : Array[&@IR.Value] = Array::new()
              indices.push(zero)
              indices.push(zero)
              self.builder.createGEP(val, arr_llvm_ty, indices)
            }
            _ => {
              let llvm_ty = self.ctype_to_llvm_type(cty)
              self.builder.createLoad(llvm_ty, val)
            }
          }
        None => val // Function parameters or other direct values
      }
    // Not a local variable, check if it's a function
    // TODO: incorrect implementation, 
    // if not local variable, it could also be a global variable.
    None => self.get_or_declare_function(name)
  }
}

///|
test "PrimExpr Codegen Test" {
  // Return int
  let code =
    #|int demo() { return 42; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i32 @demo() {
      #|entry:
      #|  ret i32 42
      #|}
      #|
    ),
  )

  // Return long
  let code =
    #|long demo() { return 2l; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i64 @demo() {
      #|entry:
      #|  ret i64 2
      #|}
      #|
    ),
  )

  // Return unsigned int
  let code =
    #|unsigned demo() { return 3u; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i32 @demo() {
      #|entry:
      #|  ret i32 3
      #|}
      #|
    ),
  )

  // Return unsigned long
  let code =
    #|unsigned long demo() { return 4ul; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i64 @demo() {
      #|entry:
      #|  ret i64 4
      #|}
      #|
    ),
  )

  // Return long long
  let code =
    #|long long demo() { return 5ull; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i64 @demo() {
      #|entry:
      #|  ret i64 5
      #|}
      #|
    ),
  )

  // Return float
  let code =
    #|float demo() { return 9.5f; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define float @demo() {
      #|entry:
      #|  ret float 0x4023000000000000
      #|}
      #|
    ),
  )

  // Return double
  let code =
    #|double demo() { return 10.0; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define double @demo() {
      #|entry:
      #|  ret double 0x4024000000000000
      #|}
      #|
    ),
  )

  // Return char
  let code =
    #|char demo() { return 'c'; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i8 @demo() {
      #|entry:
      #|  ret i8 99
      #|}
      #|
    ),
  )

  // Return string
  let code =
    #|char* demo() { return "hello"; }
  let llvm_mod = codegen(code)
  inspect(
    llvm_mod,
    content=(
      #|;; ModuleID = 'demo'
      #|;; Source File = "demo"
      #|;; Generated by MoonLLVM, not llvm
      #|
      #|@gstr1 = private unnamed_addr constant [6 x i8] c"hello\00", align 1
      #|
      #|define ptr @demo() {
      #|entry:
      #|  ret ptr @gstr1
      #|}
      #|
    ),
  )

  // Return variable
  let code =
    #|int demo() { int x = 100; return x; }
  let llvm_mod = codegen(code)
  let f = llvm_mod.getFunction("demo").unwrap()
  inspect(
    f,
    content=(
      #|define i32 @demo() {
      #|entry:
      #|  %0 = alloca i32, align 4
      #|  store i32 100, ptr %0, align 4
      #|  %2 = load i32, ptr %0, align 4
      #|  ret i32 %2
      #|}
      #|
    ),
  )
}
