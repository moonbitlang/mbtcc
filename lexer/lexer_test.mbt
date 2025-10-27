
test "Tokenize Keyword test" {
  let code = 
    #|void char short int long float double signed
    #|unsigned _Bool _Complex _Imaginary auto register
    #|static extern typedef typeof __thread _Thread_local 
    #|if else switch case default for while do goto
    #|break continue return const volatile restrict 
    #|__restrict__ __restrict _Atomic atomic inline 
    #|__inline__ _Noreturn struct union enum sizeof _Alignas
    #|_Alignof _Static_assert _Generic __attribute__ __builtin_offsetof

  let lexer_ctx = Context::new(code~, source_file="demo")
  let tokens = lexer_ctx.tokenize()
  assert_true(tokens.length() is 53)
  inspect(tokens[0].kind, content="void")
  inspect(tokens[1].kind, content="char")
  inspect(tokens[2].kind, content="short")
  inspect(tokens[3].kind, content="int")
  inspect(tokens[4].kind, content="long")
  inspect(tokens[5].kind, content="float")
  inspect(tokens[6].kind, content="double")
  inspect(tokens[7].kind, content="signed")
  inspect(tokens[8].kind, content="unsigned")
  inspect(tokens[9].kind, content="_Bool")
  inspect(tokens[10].kind, content="_Complex")
  inspect(tokens[11].kind, content="_Imaginary")
  inspect(tokens[12].kind, content="auto")
  inspect(tokens[13].kind, content="register")
  inspect(tokens[14].kind, content="static")
  inspect(tokens[15].kind, content="extern")
  inspect(tokens[16].kind, content="typedef")
  inspect(tokens[17].kind, content="typeof")
  inspect(tokens[18].kind, content="__thread")
  inspect(tokens[19].kind, content="_Thread_local")
  inspect(tokens[20].kind, content="if")
  inspect(tokens[21].kind, content="else")
  inspect(tokens[22].kind, content="switch")
  inspect(tokens[23].kind, content="case")
  inspect(tokens[24].kind, content="default")
  inspect(tokens[25].kind, content="for")
  inspect(tokens[26].kind, content="while")
  inspect(tokens[27].kind, content="do")
  inspect(tokens[28].kind, content="goto")
  inspect(tokens[29].kind, content="break")
  inspect(tokens[30].kind, content="continue")
  inspect(tokens[31].kind, content="return")
  inspect(tokens[32].kind, content="const")
  inspect(tokens[33].kind, content="volatile")
  inspect(tokens[34].kind, content="restrict")
  inspect(tokens[35].kind, content="restrict")
  inspect(tokens[36].kind, content="restrict")
  inspect(tokens[37].kind, content="atomic")
  inspect(tokens[38].kind, content="atomic")
  inspect(tokens[39].kind, content="inline")
  inspect(tokens[40].kind, content="inline")
  inspect(tokens[41].kind, content="_Noreturn")
  inspect(tokens[42].kind, content="struct")
  inspect(tokens[43].kind, content="union")
  inspect(tokens[44].kind, content="enum")
  inspect(tokens[45].kind, content="sizeof")
  inspect(tokens[46].kind, content="_Alignas")
  inspect(tokens[47].kind, content="_Alignof")
  inspect(tokens[48].kind, content="_Static_assert")
  inspect(tokens[49].kind, content="_Generic")
  inspect(tokens[50].kind, content="__attribute__")
  inspect(tokens[51].kind, content="__builtin_offsetof")
  inspect(tokens[52].kind, content="<EOF>")
}
