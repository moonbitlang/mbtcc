pub enum Token {
  // Keywords
  Void
  Char
  Short
  Int
  Long
  Float
  Double
  Signed
  Unsigned
  Bool  // _Bool
  Complex  // _Complex
  Imaginary  // _Imaginary
  Auto
  Register
  Static
  Extern
  Typedef
  ThreadLocal  // _Thread_local
  If
  Else
  Switch
  Case
  Default
  For
  While
  Do
  Goto
  Break
  Continue
  Return
  Const
  Volatile
  Restrict
  Atomic
  Inline
  Noreturn // _Noreturn
  Struct
  Union
  Enum
  Sizeof
  Alignas  // _Alignas
  Alignof  // _Alignof
  StaticAssert  // _Static_assert
  Generic

  // Brackets

  LParen // (
  RParen // )
  LBracket // [
  RBracket // ]
  LBrace // {
  RBrace // }

  // Operators

  Plus // +
  Minus // -
  Slash // /
  Star // *
  Mod   // %
  PlusPlus // ++
  MinusMinus // --

  EQ // ==
  NE // !=
  LT // <
  LE // <=
  GT // >
  GE // >=

  Assign // =
  StarAssign // *=
  DivAssign // /=
  ModAssign // %=
  PlusAssign // +=
  MinusAssign // -=
  LeftShiftAssign // <<=
  RightShiftAssign // >>=
  AndAssign // &&=
  OrAssign // ||=
  BitAndAssign // &=
  BitXorAssign // ^=
  BitOrAssign // |=

  And // &
  Or // |
  Not // !
  Xor // ^
  Tilde // ~

  DoubleAnd // &&
  DoubleOr // ||

  Shl // <<
  Shr // >>

  Comma // ,
  Dot // .
  Arrow // ->

  Colon // :
  Semi // ;
  Ellipsis // ...
  Question // ?

  Identifier(String)
  Constant(Constant)
  StringLiteral(String)
  EOF
} derive(Show, Eq)

pub enum Constant {
  Int(Int)
  //UInt(UInt)
  //Long(Int64)
  //ULong(UInt64)
  //Float(Float)
  //Double(Double)
  Char(Char)
} derive(Show, Eq)

pub suberror LexerError String derive(Show)

pub fn Context::tokenize(self: Self) -> Unit raise {
  let tokens = self.alltoks

  loop self.code[:] {
    [] => { tokens.push (EOF); break }
    [' ' | '\n' | '\r' | '\t', .. rest] => continue rest
    [.. "//", ..rest ] => 
      continue loop rest {
          ['\n' | '\r', .. rest_str] => break rest_str
          [_, .. rest_str] => continue rest_str
          [] as rest_str => break rest_str
        }
    [.."/*", .. rest] => 
      continue loop rest {
          [.."*/", .. rest_str] => break rest_str
          [_, .. rest_str] => continue rest_str
          [] as rest_str => break rest_str
        }
    [.. "<<=", ..rest] => { tokens.push(LeftShiftAssign); continue rest }
    [.. ">>=", ..rest] => { tokens.push(RightShiftAssign); continue rest }
    [.. "&&=", ..rest] => { tokens.push(AndAssign); continue rest }
    [.. "||=", ..rest] => { tokens.push(OrAssign); continue rest }
    [.. "<<", ..rest] => { tokens.push(Shl); continue rest }
    [.. ">>", ..rest] => { tokens.push(Shr); continue rest }
    [.. "++", ..rest] => { tokens.push(PlusPlus); continue rest }
    [.. "--", ..rest] => { tokens.push(MinusMinus); continue rest }
    [.. "->", ..rest] => { tokens.push(Arrow); continue rest }
    [.. "...", ..rest] => { tokens.push(Ellipsis); continue rest }
    [.. "==", ..rest] => { tokens.push(EQ); continue rest }
    [.. "!=", ..rest] => { tokens.push(NE); continue rest }
    [.. "<=", ..rest] => { tokens.push(LE); continue rest }
    [.. "<", ..rest] => { tokens.push(LT); continue rest }
    [.. ">=", ..rest] => { tokens.push(GE); continue rest }
    [.. ">", ..rest] => { tokens.push(GT); continue rest }
    [.. "&&", ..rest] => { tokens.push(DoubleAnd); continue rest }
    [.. "||", ..rest] => { tokens.push(DoubleOr); continue rest }
    [.. "*=", ..rest] => { tokens.push(StarAssign); continue rest }
    [.. "/=", ..rest] => { tokens.push(DivAssign); continue rest }
    [.. "%=", ..rest] => { tokens.push(ModAssign); continue rest }
    [.. "+=", ..rest] => { tokens.push(PlusAssign); continue rest }
    [.. "-=", ..rest] => { tokens.push(MinusAssign); continue rest }
    [.. "&=", ..rest] => { tokens.push(BitAndAssign); continue rest }
    [.. "^=", ..rest] => { tokens.push(BitXorAssign); continue rest }
    [.. "|=", ..rest] => { tokens.push(BitOrAssign); continue rest }
    ['(', ..rest] => { tokens.push(LParen); continue rest }
    [')', ..rest] => { tokens.push(RParen); continue rest }
    ['[', ..rest] => { tokens.push(LBracket); continue rest }
    [']', ..rest] => { tokens.push(RBracket); continue rest }
    ['{', ..rest] => { tokens.push(LBrace); continue rest }
    ['}', ..rest] => { tokens.push(RBrace); continue rest }
    [';', ..rest] => { tokens.push(Semi); continue rest }
    [':', ..rest] => { tokens.push(Colon); continue rest }
    ['.', ..rest] => { tokens.push(Dot); continue rest }
    [',', ..rest] => { tokens.push(Comma); continue rest }
    ['+', ..rest] => { tokens.push(Plus); continue rest }
    ['-', ..rest] => { tokens.push(Minus); continue rest }
    ['*', ..rest] => { tokens.push(Star); continue rest }
    ['/', ..rest] => { tokens.push(Slash); continue rest }
    ['%', ..rest] => { tokens.push(Mod); continue rest }
    ['&', ..rest] => { tokens.push(And); continue rest }
    ['|', ..rest] => { tokens.push(Or); continue rest }
    ['^', ..rest] => { tokens.push(Xor); continue rest }
    ['!', ..rest] => { tokens.push(Not); continue rest }
    ['?', ..rest] => { tokens.push(Question); continue rest }
    ['~', ..rest] => { tokens.push(Tilde); continue rest }
    ['=', ..rest] => { tokens.push(Assign); continue rest }
    ['\'', ..] as code => {
      let (tok, rest) = lex_char_literal(code)
      tokens.push(tok)
      continue rest
    }
    //['\'', ..] as code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
    ['"', ..] as code => {
      let (tok, rest) = lex_string_literal(code)
      tokens.push(tok)
      continue rest
    }
    ['0'..='9', ..] as code => {
      let (tok, rest) = lex_number(code)
      tokens.push(tok)
      continue rest
    }
    ['a' ..='z' | 'A' ..='Z' | '_', ..] as code => {
      let (tok, rest) = lex_ident(code)
      tokens.push(tok)
      continue rest
    }
    code => raise LexerError("Parse Error: Unexpected char: \{code[0]}")
  }
  self.rest_toks = self.alltoks[:]
}

fn lex_string_literal(code: @string.View) -> (Token, @string.View) raise {
  guard code is ['"', .. code] // skip first '"'
  let str = Array::new()
  let rest = loop code {
    ['"', .. rest_str] => break rest_str
    [.."\\n", .. rest_str] => { str.push('\n'); continue rest_str }
    [.."\\r", .. rest_str] => { str.push('\r'); continue rest_str }
    [.."\\t", .. rest_str] => { str.push('\t'); continue rest_str }
    [.."\\\"", .. rest_str] => { str.push('"'); continue rest_str }
    [.."\\\\", .. rest_str] => { str.push('\\'); continue rest_str }
    ['\n', ..] => raise LexerError("Parse Error: Unclosed string literal, found newline")
    [c, .. rest_str] => {
      str.push(c)
      continue rest_str
    }
    [] => raise LexerError("Parse Error: Unclosed string literal")
  }
  let str = String::from_array(str)
  (StringLiteral(str), rest)
}

fn lex_char_literal(code: @string.View) -> (Token, @string.View) raise {
  guard code is ['\'', .. code]
  match code {
    [.."\\n", '\'', .. rest_str] => (Constant(Char('\n')), rest_str)
    [.."\\r", '\'', .. rest_str] => (Constant(Char('\r')), rest_str)
    [.."\\t", '\'', .. rest_str] => (Constant(Char('\t')), rest_str)
    [.."\\\'", '\'', .. rest_str] => (Constant(Char('\'')), rest_str)
    [c, '\'', .. rest_str] => (Constant(Char(c)), rest_str)
    ['\'', ..] => raise LexerError("Empty char literal")
    code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
  }
}

// @strconv.parse_int: (String, Int) -> Int, input is string and base, return an int
// @strconv.parse_int64: (String, Int) -> Int64, input is string and base, return an int
// @strconv.parse_double: (String, Int) -> Double, input is string and base, return an int
fn lex_number(code: @string.View) -> (Token, @string.View) raise {
  let num = Array::new()
  let rest = loop code {
    ['0'..='9' as c, .. rest_str] => {
      num.push(c)
      continue rest_str
    }
    _ as rest_str => break rest_str
  }
  let numstr = String::from_array(num)
  let num = @strconv.parse_int(numstr, base=10)
  let num = Constant::Int(num)
  (Constant(num), rest)
}

let keywords : Map[String, Token] = {
  "void" : Void,
  "char" : Char,
  "short" : Short,
  "int" : Int,
  "long" : Long,
  "float" : Float,
  "double" : Double,
  "signed" : Signed,
  "unsigned" : Unsigned,
  "_Bool" : Bool,
  "_Complex" : Complex,
  "_Imaginary" : Imaginary,
  "auto" : Auto,
  "register" : Register,
  "static" : Static,
  "extern" : Extern,
  "typedef" : Typedef,
  "_Thread_local" : ThreadLocal,
  "if" : If,
  "else" : Else,
  "switch" : Switch,
  "case" : Case,
  "default" : Default,
  "for" : For,
  "while" : While,
  "do" : Do,
  "goto" : Goto,
  "break" : Break,
  "continue" : Continue,
  "return" : Return,
  "const" : Const,
  "volatile" : Volatile,
  "restrict" : Restrict,
  "atomic" : Atomic,
  "inline" : Inline,
  "__inline__" : Inline, // GNU extension
  "_Noreturn" : Noreturn,
  "struct" : Struct,
  "union" : Union,
  "enum" : Enum,
  "sizeof" : Sizeof,
  "_Alignas" : Alignas,
  "_Alignof" : Alignof,
  "_Static_assert" : StaticAssert,
  "_Generic" : Generic,
}

fn lex_ident(code: @string.View) -> (Token, @string.View) {
  let ident = Array::new()
  let rest_str = loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' as c, .. rest_str] => {
      ident.push(c)
      continue rest_str
    }
    _ as rest_str => break rest_str
  }
  let ident = String::from_array(ident)
  let tok = match keywords.get(ident) {
    Some(token) => token
    None => Identifier(ident)
  }
  (tok, rest_str)
}

test "tokenize test" {
  let code = 
    #|int void char short long float double signed unsigned _Bool _Complex
    #|_Imaginary auto register static extern typedef _Thread_local if else
    #|switch case default for while do goto break continue return const
    #|volatile restrict atomic inline _Noreturn struct union enum sizeof
    #|_Alignas _Alignof _Static_assert _Generic
    #|
    #| () [] {}
    #| + - * / % >> <<
    #| ++ -- ->
    #| < > >= <= == !=
    #| = *= /= %= += -= <<= >>= &&= ||= &= ^= |=
    #| & | ! ^ ~
    #| && ||
    #| , . : ; ? ...
    #| "hello, world" "hello\n" "hello\r" "hello\t" "\"hello\"" "hello\\"
    #| 'c' '\n' '\r' '\t' '\'' '"'
    #| 123 xyz a123

  // TODO:
  // #| 0x123, 1L, 2L, 3U, 4UL, 
  // #| 5.0 6.125, 7.0f, 8.0F, 9.0e2, 10.0E-2, 11.0e+2, 12.0E+2,
  // #| 0x1.2p+2, 0x1.2P+2, 0x1.2p-2, 0x1.2P-2

  let expect : Array[Token] = [
    Int, Void, Char, Short, Long, Float, Double, Signed, Unsigned, Bool, Complex,
    Imaginary, Auto, Register, Static, Extern, Typedef, ThreadLocal, If, Else,
    Switch, Case, Default, For, While, Do, Goto, Break, Continue, Return, Const,
    Volatile, Restrict, Atomic, Inline, Noreturn, Struct, Union, Enum, Sizeof,
    Alignas, Alignof, StaticAssert, Generic,
    LParen, RParen, LBracket, RBracket, LBrace, RBrace,
    Plus, Minus, Star, Slash, Mod, Shr, Shl,
    PlusPlus, MinusMinus, Arrow,
    LT, GT, GE, LE, EQ, NE,
    Assign, StarAssign, DivAssign, ModAssign, PlusAssign, MinusAssign,
    LeftShiftAssign, RightShiftAssign, AndAssign, OrAssign,
    BitAndAssign, BitXorAssign, BitOrAssign,
    And, Or, Not, Xor, Tilde, DoubleAnd, DoubleOr,
    Comma, Dot, Colon, Semi, Question, Ellipsis,
    StringLiteral("hello, world"), StringLiteral("hello\n"), StringLiteral("hello\r"), 
    StringLiteral("hello\t"), StringLiteral("\"hello\""), StringLiteral("hello\\"),
    Constant(Char('c')), Constant(Char('\n')), Constant(Char('\r')), Constant(Char('\t')), Constant(Char('\'')), Constant(Char('"')),
    Constant(Int(123)),
    Identifier("xyz"), Identifier("a123"), EOF
  ]

  let ctx = Context::create(code)
  ctx.tokenize()
  for i in 0..<expect.length() {
    assert_eq(ctx.alltoks.get(i), Some(expect[i]), msg="Tokenization Test Failed at index \{i}, expect \{expect[i]} got \{ctx.alltoks[i]}")
  }
}

test "tokenize comment test" {
  let code = 
    #|int void // check if comment works
    #|char short
    #|123 /* check if inline comment works */
    #|
    #|unsigned /* check
    #| if multiline
    #| comment works
    #| */
    #|
    #|, 
    #|

  let expect : Array[Token] = [
    Int, Void, Char, Short, Constant(Int(123)), Unsigned, Comma, EOF
  ]
  let ctx = Context::create(code)
  ctx.tokenize()
  for i in 0..<expect.length() {
    assert_eq(ctx.alltoks.get(i), Some(expect[i]), msg="Tokenization Test Failed at index \{i}, expect \{expect[i]} got \{ctx.alltoks[i]}")
  }
}

test "tokenize error test" {
  let code = "\"hello"
  let ctx = Context::create(code)
  assert_true((try? ctx.tokenize()) is Err(_), msg = "Tokenization should fail for unclosed string literal")

  let code = "'c"
  let ctx = Context::create(code)
  assert_true((try? ctx.tokenize()) is Err(_), msg = "Tokenization should fail for unclosed char literal")

  let code = "''"
  let ctx = Context::create(code)
  assert_true((try? ctx.tokenize()) is Err(_), msg = "Tokenization should fail for empty char literal")

  let code = 
    #|"hello
    #|
  let ctx = Context::create(code)
  assert_true((try? ctx.tokenize()) is Err(_), msg = "Tokenization should fail for unclosed string literal")

  let code = "中"
  let ctx = Context::create(code)
  assert_true((try? ctx.tokenize()) is Err(_), msg = "Tokenization should fail for non-ASCII character")
}
