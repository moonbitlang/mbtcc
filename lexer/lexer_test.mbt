///|
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
  inspect(tokens.length(), content="53")
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

///|
test "Tokenize Operator and Symbols Test" {
  let code =
    #| () [] {}
    #| + - * / % >> <<
    #| ++ -- ->
    #| < > >= <= == !=
    #| = *= /= %= += -= <<= >>= &&= ||= &= ^= |=
    #| & | ! ^ ~
    #| && ||
    #| , . : ; ? ...
  let lexer_ctx = Context::new(code~, source_file="demo")
  let tokens = lexer_ctx.tokenize()
  inspect(tokens.length(), content="49")
  inspect(tokens[0].kind, content="(")
  inspect(tokens[1].kind, content=")")
  inspect(tokens[2].kind, content="[")
  inspect(tokens[3].kind, content="]")
  inspect(tokens[4].kind, content="{")
  inspect(tokens[5].kind, content="}")
  inspect(tokens[6].kind, content="+")
  inspect(tokens[7].kind, content="-")
  inspect(tokens[8].kind, content="*")
  inspect(tokens[9].kind, content="/")
  inspect(tokens[10].kind, content="%")
  inspect(tokens[11].kind, content=">>")
  inspect(tokens[12].kind, content="<<")
  inspect(tokens[13].kind, content="++")
  inspect(tokens[14].kind, content="--")
  inspect(tokens[15].kind, content="->")
  inspect(tokens[16].kind, content="<")
  inspect(tokens[17].kind, content=">")
  inspect(tokens[18].kind, content=">=")
  inspect(tokens[19].kind, content="<=")
  inspect(tokens[20].kind, content="==")
  inspect(tokens[21].kind, content="!=")
  inspect(tokens[22].kind, content="=")
  inspect(tokens[23].kind, content="*=")
  inspect(tokens[24].kind, content="/=")
  inspect(tokens[25].kind, content="%=")
  inspect(tokens[26].kind, content="+=")
  inspect(tokens[27].kind, content="-=")
  inspect(tokens[28].kind, content="<<=")
  inspect(tokens[29].kind, content=">>=")
  inspect(tokens[30].kind, content="&&=")
  inspect(tokens[31].kind, content="||=")
  inspect(tokens[32].kind, content="&=")
  inspect(tokens[33].kind, content="^=")
  inspect(tokens[34].kind, content="|=")
  inspect(tokens[35].kind, content="&")
  inspect(tokens[36].kind, content="|")
  inspect(tokens[37].kind, content="!")
  inspect(tokens[38].kind, content="^")
  inspect(tokens[39].kind, content="~")
  inspect(tokens[40].kind, content="&&")
  inspect(tokens[41].kind, content="||")
  inspect(tokens[42].kind, content=",")
  inspect(tokens[43].kind, content=".")
  inspect(tokens[44].kind, content=":")
  inspect(tokens[45].kind, content=";")
  inspect(tokens[46].kind, content="?")
  inspect(tokens[47].kind, content="...")
  inspect(tokens[48].kind, content="<EOF>")
}

///|
test "Tokenize Identifier Test" {
  let code =
    #|myVar another_var _privateVar Var123 __init__ main
    #|if_else forloop switch_case default_case
    #|struct$union typedefname
  let lexer_ctx = Context::new(code~, source_file="demo")
  let tokens = lexer_ctx.tokenize()
  inspect(tokens.length(), content="13")
  inspect(tokens[0].kind, content="myVar")
  inspect(tokens[1].kind, content="another_var")
  inspect(tokens[2].kind, content="_privateVar")
  inspect(tokens[3].kind, content="Var123")
  inspect(tokens[4].kind, content="__init__")
  inspect(tokens[5].kind, content="main")
  inspect(tokens[6].kind, content="if_else")
  inspect(tokens[7].kind, content="forloop")
  inspect(tokens[8].kind, content="switch_case")
  inspect(tokens[9].kind, content="default_case")
  inspect(tokens[10].kind, content="struct$union")
  inspect(tokens[11].kind, content="typedefname")
  inspect(tokens[12].kind, content="<EOF>")
}

///|
test "Tokenize Number Literal Test" {
  let code =
    #|1 2 3 12 34 12345678
    #|0x1 0x2a 0xfF 0XABCDEF
    #|0b101 0B1101 0b11111111
    #|07 0123 0777
    #|3.14 0.001 123.456e10 6.022e23
    #|1u 2l 3ul 4ll 5ull
    #|6U 7L 8UL 9LL 10ULL
    #|0.5f 1.5F 2.5l 3.5L
  // TODO:
  // Add support for hexadecimal floating point literals like 0x1.91p+1
  let lexer_ctx = Context::new(code~, source_file="demo")
  let tokens = lexer_ctx.tokenize()
  inspect(tokens.length(), content="35")
  inspect(tokens[0].kind, content="1")
  inspect(tokens[1].kind, content="2")
  inspect(tokens[2].kind, content="3")
  inspect(tokens[3].kind, content="12")
  inspect(tokens[4].kind, content="34")
  inspect(tokens[5].kind, content="12345678")
  inspect(tokens[6].kind, content="1")
  inspect(tokens[7].kind, content="42")
  inspect(tokens[8].kind, content="255")
  inspect(tokens[9].kind, content="11259375")
  inspect(tokens[10].kind, content="5")
  inspect(tokens[11].kind, content="13")
  inspect(tokens[12].kind, content="255")
  inspect(tokens[13].kind, content="7")
  inspect(tokens[14].kind, content="83")
  inspect(tokens[15].kind, content="511")
  inspect(tokens[16].kind, content="3.14")
  inspect(tokens[17].kind, content="0.001")
  inspect(tokens[18].kind, content="1234560000000")
  inspect(tokens[19].kind, content="6.022e+23")
  inspect(tokens[20].kind, content="1u")
  inspect(tokens[21].kind, content="2l")
  inspect(tokens[22].kind, content="3ul")
  inspect(tokens[23].kind, content="4ll")
  inspect(tokens[24].kind, content="5ull")
  inspect(tokens[25].kind, content="6u")
  inspect(tokens[26].kind, content="7l")
  inspect(tokens[27].kind, content="8ul")
  inspect(tokens[28].kind, content="9ll")
  inspect(tokens[29].kind, content="10ull")
  inspect(tokens[30].kind, content="0.5f")
  inspect(tokens[31].kind, content="1.5f")
  inspect(tokens[32].kind, content="2.5")
  inspect(tokens[33].kind, content="3.5")
  inspect(tokens[34].kind, content="<EOF>")
}

///|
test "Tokenize String Literal Test" {
  let code =
    #|"Hello, World!" "This is a test." ""
    #|"String with \n new line"
    #|"Escaped quote: \" inside"
    #|"Backslash: \\ inside"
  let lexer_ctx = Context::new(code~, source_file="demo")
  let tokens = lexer_ctx.tokenize()
  inspect(tokens.length(), content="7")
  inspect(
    tokens[0].kind,
    content=(
      #|"Hello, World!"
    ),
  )
  inspect(
    tokens[1].kind,
    content=(
      #|"This is a test."
    ),
  )
  inspect(
    tokens[2].kind,
    content=(
      #|""
    ),
  )
  inspect(
    tokens[3].kind,
    content=(
      #|"String with \n new line"
    ),
  )
  inspect(
    tokens[4].kind,
    content=(
      #|"Escaped quote: \" inside"
    ),
  )
  inspect(
    tokens[5].kind,
    content=(
      #|"Backslash: \\ inside"
    ),
  )
  inspect(tokens[6].kind, content="<EOF>")
}

///|
test "Tokenize Character Literal Test" {
  let code =
    #|'a' 'Z' '0' '\n' '\'' '"' '\\' '\0' '\t' '\r'
  let lexer_ctx = Context::new(code~, source_file="demo")
  let tokens = lexer_ctx.tokenize()
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="a")
  inspect(tokens[1].kind, content="Z")
  inspect(tokens[2].kind, content="0")
  inspect(tokens[3].kind, content="\n")
  inspect(tokens[4].kind, content="'")
  inspect(tokens[5].kind, content="\"")
  inspect(tokens[6].kind, content="\\")
  inspect(tokens[7].kind, content="\u{0}")
  inspect(tokens[8].kind, content="\t")
  inspect(tokens[9].kind, content="\r")
  inspect(tokens[10].kind, content="<EOF>")
}
