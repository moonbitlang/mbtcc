///|
pub suberror CodeGenError {
  Unimplemented(String)
  IllegalLLVMUsage(String)
  SemanticError(String)
} derive(Show)
