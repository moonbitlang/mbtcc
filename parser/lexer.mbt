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
  AndAssign // &=
  XorAssign // ^=
  OrAssign // |=

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

pub fn lex(code: String) -> Array[Token] raise {
  let tokens : Array[Token] = Array::new()

  loop code[:] {
    [] => { tokens.push (EOF); break tokens }
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
    [.. "&=", ..rest] => { tokens.push(AndAssign); continue rest }
    [.. "^=", ..rest] => { tokens.push(XorAssign); continue rest }
    [.. "|=", ..rest] => { tokens.push(OrAssign); continue rest }
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
    ['~', ..rest] => { tokens.push(Tilde); continue rest }
    ['=', ..rest] => { tokens.push(Assign); continue rest }
    ['\'', c, '\'', ..rest] => { tokens.push(Constant(Char(c))); continue rest }
    ['\'', ..] as code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
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
    _ => raise LexerError("Parse Error: Unexpected char: \{code[0]}")
  }
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
    [c, .. rest_str] => {
      str.push(c)
      continue rest_str
    }
    [] => raise LexerError("Parse Error: Unclosed string literal")
  }
  let str = String::from_array(str)
  (StringLiteral(str), rest)
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

test "lexing test" {

  let code = 
    #|typedef struct {
    #|  int x;
    #|  int y;
    #|} Point;
    #| 
    #|void init_point(Point *p) {
    #|  if (p != NULL) {
    #|    p->x = 0;
    #|    p->y = 0;
    #|  }
    #|}
    #|
    #|int main() {
    #|  Point p;
    #|  init_point(&p);
    #|  p.x = 3;
    #|  p.y = 4;
    #|  printf("Point: (%d, %d)\n", p.x, p.y);
    #|  return 0;
    #|}

  let toks = lex(code)
  let expect = [
    Typedef, Struct, LBrace,
    Int,Identifier("x"), Semi,
    Int, Identifier("y"), Semi, 
    RBrace, Identifier("Point"), Semi,
    Void, Identifier("init_point"), LParen, Identifier("Point"), Star,
    Identifier("p"), RParen, LBrace, If, LParen, Identifier("p"), NE,
    Identifier("NULL"), RParen, LBrace,
    Identifier("p"), Arrow, Identifier("x"), Assign,
    Constant(Int(0)), Semi, Identifier("p"),
    Arrow, Identifier("y"), Assign, Constant(Int(0)),
    Semi, RBrace, RBrace,
    Int, Identifier("main"), LParen, RParen, LBrace,
    Identifier("Point"), Identifier("p"), Semi,
    Identifier("init_point"), LParen, And,
    Identifier("p"), RParen, Semi, Identifier("p"), Dot,
    Identifier("x"), Assign, Constant(Int(3)),
    Semi, Identifier("p"), Dot, Identifier("y"),
    Assign, Constant(Int(4)), Semi, Identifier("printf"),
    LParen, StringLiteral("Point: (%d, %d)\n"), Comma, Identifier("p"),
    Dot, Identifier("x"), Comma, Identifier("p"),
    Dot, Identifier("y"), RParen, Semi, Return,
    Constant(Int(0)), Semi, RBrace, EOF
  ]
  assert_eq(toks, expect, msg="Lexing Test Failed")
}

test "lex number test" {
  let code_expect : Map[String, Array[Token]] = {
    "1" : [Constant(Int(1))],
    //"1L" : [Constant(Long(1L))],
    //"1l" : [Constant(Long(1L))],
    //"1U" : [Constant(UInt(1))],
    //"1UL" : [Constant(ULong(1UL))],
    //"1.0": [Constant(Double(1.0))],
    //"1.0f": [Constant(Float(1.0))],
    //"0x1" : [Constant(Int(1))],
    //"0x10" : [Constant(Int(16))],
    //"0xf" : [Constant(Int(15))],
    //"0xff" : [Constant(Int(255))],
    //"0b10" : [Constant(Int(2))],
    //"0o10" : [Constant(Int(8))],
    //"1e1"  : [Constant(Double(10.0))],
    //"1.2e1"  : [Constant(Double(12.0))],
    //"1.25e+2"  : [Constant(Double(125.0))],
    //"1.25e-2"  : [Constant(Double(0.0125))],
    //"0x1.2p+2" : [Constant(Double(4.8))],  // need to check this value if it is correct
  }

  for code, expect in code_expect {
    let (tok, _) = lex_number(code)
    assert_eq([tok], expect, msg="Lexing number \{code} failed")
  }
}
