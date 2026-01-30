///|
pub fn codegen(
  code : String,
  source_file? : String = "demo",
) -> @IR.Module raise {
  let parse_ctx = @parser.Context::new(code~, source_file~)
  let _ = parse_ctx.parse()
  let codegen_ctx = Context::init_from_parse_program(parse_ctx)
  codegen_ctx.emit()
}

///|
pub fn codegen_from_parser(parse_ctx : @parser.Context) -> Context {
  guard !parse_ctx.prog.is_empty() else {
    println("Compiler ICE: cannot codegen from empty program")
    panic()
  }
  Context::init_from_parse_program(parse_ctx)
}
