///|
#callsite(autofill(loc))
fn[T] codegen_unreachable(loc~ : SourceLoc, msg? : String = "") -> T {
  println("Compiler ICE: reached unreachable code: \{loc}")
  if !msg.is_empty() {
    println("  - \{msg}")
  }
  panic()
}
