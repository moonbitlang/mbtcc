fn main {
  let code = "int"
  let ctx = @parser.Context::new(code~, source_file="demo")
  let (ty, rest) = ctx.parse_type_name(ctx.tokens) catch {
    _ => { println("Error Happened"); return }
  }
  println(ty)
  println(rest)
}
