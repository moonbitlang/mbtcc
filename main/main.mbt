///|
fn main {
  let args = @env.args()
  let help_info =
    #|Usgae: mbtcc [options]
    #|
    #|  -code <code>    : Compile the given code string.
    #|  -file <file>    : Compile the code from the specified file.
    #|  --print-toks    : Print the tokens after lexing.
    #|  --stop-after=lex : Stop after lexing phase.
    #|  --stop-after=parse : Stop after parsing phase.
    #|  --help         : Show this help message.
  if args.length() == 1 {
    println(help_info)
    return
  }
  if args.contains("--help") {
    println(help_info)
    return
  }
  let ctx = match args.search_by(a => a is "-file" || a is "--file") {
    Some(idx) if idx + 1 < args.length() =>
      @parser.ParserContext::create_by_file(args[idx + 1])
    Some(_) => {
      println("Error: No file specified after -file option")
      return
    }
    None =>
      match args.search_by(a => a is "-code" || a is "--code") {
        Some(idx) if idx + 1 < args.length() =>
          @parser.ParserContext::create_by_code(args[idx + 1])
        Some(_) => {
          println("Error: No code specified after -code option")
          return
        }
        None => {
          println(help_info)
          return
        }
      }
  }
  ctx.tokenize() catch {
    err => {
      println("Tokenization error: \{err}")
      return
    }
  }
  ctx.preprocess() catch {
    err => {
      println("Preprocessing error: \{err}")
      return
    }
  }
  if args.contains("--print-toks") {
    ctx.print_toks()
  }
  if args.contains("--stop-after=lex") {
    return
  }
  ctx.parse() catch {
    @parser.ParseError((idx, msg)) => {
      let msg = ctx.get_error_msg(idx, msg)
      println("Parse error: " + msg)
      return
    }
    _ => ()
  }
  if args.contains("--print-ast") {
    ctx.print_ast()
  }
  if args.contains("--stop-after=parse") {
    return
  }
  let codegen = @parser.CodeGenContext::from_parser(ctx)
  codegen.run() catch {
    err => {
      println("Code generation error: \{err}")
      return
    }
  }
  //if args.contains("--print-llvm") {
  //  codegen.dump()
  //}
  if !args.contains("--no-print-llvm") { // temporary
    codegen.dump()
  }
}
