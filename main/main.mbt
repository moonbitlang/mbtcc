//fn main {
//  let code = 
//    #|int main() {
//    #|  int a, b= 3;
//    #|  a = fact(b);
//    #|  printf("%d\n", a;
//    #|  return 0;
//    #|}
//
//  let ctx = @parser.Context::create(code)
//  ctx.tokenize() catch {
//    err => println(err)
//  }
//
//  ctx.parse() catch {
//    @parser.ParseError((idx, msg)) => {
//      let msg = ctx.get_error_msg(idx, msg)
//      println(msg)
//    }
//    _ => ()
//  }
//
//  ctx.print_toks()
//  ctx.print_ast()
//}


fn main {
  let args = @env.args()

  guard @env.current_dir() is Some(curr_dir) else {
    println("Failed to get current directory")
    return
  }

  let filename = if args.length() > 1 {
    args[1]
  } else {
    "test.c"
  }
  let file_path = curr_dir + "/" + filename
  println(file_path)

  let code = @fs.read_file_to_string(file_path) catch {
    _ => {
      println("Failed to read file: " + file_path)
      return
    }
  }

  let ctx = @parser.Context::create(code, source_file=filename)
  ctx.tokenize() catch {
    err => { 
      println("Tokenization error: \{err}")
      return
    }
  }

  if args.contains("--stop-after=lex") {
    ctx.print_toks()
    return
  }

  println("Tokenization Passed")

  ctx.parse() catch {
    @parser.ParseError((idx, msg)) => {
      let msg = ctx.get_error_msg(idx, msg)
      println("Parse error: " + msg)
      return
    }
    _ => ()
  }

  println("Parsing Passed")
}
