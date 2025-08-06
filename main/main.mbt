fn main {
  let code = 
    #|int main() {
    #|  int a, b= 3;
    #|  a = fact(b);
    #|  printf("%d\n", a;
    #|  return 0;
    #|}

  let ctx = @parser.Context::create(code)
  ctx.tokenize() catch {
    err => println(err)
  }
  
  ctx.parse() catch {
    @parser.ParseError((idx, msg)) => {
      let msg = ctx.get_error_msg(idx, msg)
      println(msg)
    }
    _ => ()
  }

  ctx.print_toks()
  ctx.print_ast()
}
