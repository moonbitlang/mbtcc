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
  Thread
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
  Typeof
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
  let tokinfos = self.tokinfos

  let mut lineno = 1;
  let mut column = 1;
  let mut codeidx = 0;

  loop self.code[:] {
    [] => { 
      tokens.push (EOF);
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      break
    }
    ['\n', ..rest] => {
      lineno += 1
      column = 1
      codeidx += 1
      continue rest
    }
    [' ' | '\r' | '\t', .. rest] => {
      column += 1
      codeidx += 1
      continue rest
    }
    [.. "//", ..rest ] => {
      codeidx += 2 // "//" 占2个字符
      column += 2
      continue loop rest {
          ['\n' | '\r', .. rest_str] => break rest_str
          [_, .. rest_str] => {
            codeidx += 1
            column += 1
            continue rest_str
          }
          [] as rest_str => break rest_str
        }
    }
    [.."/*", .. rest] => {
      codeidx += 2 // "/*" 占2个字符
      column += 2
      continue loop rest {
          [.."*/", .. rest_str] => {
            codeidx += 2 // "*/" 占2个字符
            column += 2
            break rest_str
          }
          ['\n', .. rest_str] => {
            lineno += 1
            column = 1
            codeidx += 1
            continue rest_str
          }
          [_, .. rest_str] => {
            codeidx += 1
            column += 1
            continue rest_str
          }
          [] as rest_str => break rest_str
        }
    }
    [.. "<<=", ..rest] => {
      tokens.push(LeftShiftAssign);
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 3
      codeidx += 3
      continue rest
    }
    [.. ">>=", ..rest] => { 
      tokens.push(RightShiftAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 3
      codeidx += 3
      continue rest 
    }
    [.. "&&=", ..rest] => { 
      tokens.push(AndAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 3
      codeidx += 3
      continue rest 
    }
    [.. "||=", ..rest] => { 
      tokens.push(OrAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 3
      codeidx += 3
      continue rest 
    }
    [.. "<<", ..rest] => { 
      tokens.push(Shl); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. ">>", ..rest] => { 
      tokens.push(Shr); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "++", ..rest] => { 
      tokens.push(PlusPlus); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "--", ..rest] => { 
      tokens.push(MinusMinus); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "->", ..rest] => { 
      tokens.push(Arrow); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "...", ..rest] => { 
      tokens.push(Ellipsis); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 3
      codeidx += 3
      continue rest 
    }
    [.. "==", ..rest] => { 
      tokens.push(EQ); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "!=", ..rest] => { 
      tokens.push(NE); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "<=", ..rest] => { 
      tokens.push(LE); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "<", ..rest] => { 
      tokens.push(LT); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [.. ">=", ..rest] => { 
      tokens.push(GE); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. ">", ..rest] => { 
      tokens.push(GT); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [.. "&&", ..rest] => { 
      tokens.push(DoubleAnd); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "||", ..rest] => { 
      tokens.push(DoubleOr); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "*=", ..rest] => { 
      tokens.push(StarAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "/=", ..rest] => { 
      tokens.push(DivAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "%=", ..rest] => { 
      tokens.push(ModAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "+=", ..rest] => { 
      tokens.push(PlusAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "-=", ..rest] => { 
      tokens.push(MinusAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "&=", ..rest] => { 
      tokens.push(BitAndAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "^=", ..rest] => { 
      tokens.push(BitXorAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    [.. "|=", ..rest] => { 
      tokens.push(BitOrAssign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 2
      codeidx += 2
      continue rest 
    }
    ['(', ..rest] => { 
      tokens.push(LParen); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [')', ..rest] => { 
      tokens.push(RParen); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['[', ..rest] => { 
      tokens.push(LBracket); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [']', ..rest] => { 
      tokens.push(RBracket); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['{', ..rest] => { 
      tokens.push(LBrace); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['}', ..rest] => { 
      tokens.push(RBrace); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [';', ..rest] => { 
      tokens.push(Semi); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [':', ..rest] => { 
      tokens.push(Colon); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['.', ..rest] => { 
      tokens.push(Dot); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    [',', ..rest] => { 
      tokens.push(Comma); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['+', ..rest] => { 
      tokens.push(Plus); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['-', ..rest] => { 
      tokens.push(Minus); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['*', ..rest] => { 
      tokens.push(Star); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['/', ..rest] => { 
      tokens.push(Slash); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['%', ..rest] => { 
      tokens.push(Mod); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['&', ..rest] => { 
      tokens.push(And); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['|', ..rest] => { 
      tokens.push(Or); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['^', ..rest] => { 
      tokens.push(Xor); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['!', ..rest] => { 
      tokens.push(Not); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['?', ..rest] => { 
      tokens.push(Question); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['~', ..rest] => { 
      tokens.push(Tilde); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['=', ..rest] => { 
      tokens.push(Assign); 
      tokinfos.push(TokenInfo::{lineno, column, codeidx})
      column += 1
      codeidx += 1
      continue rest 
    }
    ['\'', ..] as code => {
      let tokinfo = TokenInfo::{lineno, column, codeidx}
      let (tok, rest, char_count) = lex_char_literal(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    //['\'', ..] as code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
    ['"', ..] as code => {
      let tokinfo = TokenInfo::{lineno, column, codeidx}
      let (tok, rest, char_count) = lex_string_literal(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    ['0'..='9', ..] as code => {
      let tokinfo = TokenInfo::{lineno, column, codeidx}
      let (tok, rest, char_count) = lex_number(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    ['a' ..='z' | 'A' ..='Z' | '_', ..] as code => {
      let tokinfo = TokenInfo::{lineno, column, codeidx}
      let (tok, rest, char_count) = lex_ident(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    code => raise LexerError("Parse Error: Unexpected char: \{code[0]}")
  }
}

fn lex_string_literal(code: @string.View) -> (Token, @string.View, Int) raise {
  guard code is ['"', .. code] // skip first '"'
  let str = Array::new()
  let mut char_count = 1 // 开始的引号
  let rest = loop code {
    ['"', .. rest_str] => {
      char_count += 1 // 结束的引号
      break rest_str
    }
    [.."\\n", .. rest_str] => { 
      str.push('\n'); 
      char_count += 2 // \n 是2个字符
      continue rest_str 
    }
    [.."\\r", .. rest_str] => { 
      str.push('\r'); 
      char_count += 2 // \r 是2个字符
      continue rest_str 
    }
    [.."\\t", .. rest_str] => { 
      str.push('\t'); 
      char_count += 2 // \t 是2个字符
      continue rest_str 
    }
    [.."\\\"", .. rest_str] => { 
      str.push('"'); 
      char_count += 2 // \" 是2个字符
      continue rest_str 
    }
    [.."\\\\", .. rest_str] => { 
      str.push('\\'); 
      char_count += 2 // \\ 是2个字符
      continue rest_str 
    }
    ['\n', ..] => raise LexerError("Parse Error: Unclosed string literal, found newline")
    [c, .. rest_str] => {
      str.push(c)
      char_count += 1 // 普通字符是1个字符
      continue rest_str
    }
    [] => raise LexerError("Parse Error: Unclosed string literal")
  }
  let str = String::from_array(str)
  (StringLiteral(str), rest, char_count)
}

fn lex_char_literal(code: @string.View) -> (Token, @string.View, Int) raise {
  guard code is ['\'', .. code]
  match code {
    [.."\\n", '\'', .. rest_str] => (Constant(Char('\n')), rest_str, 4) // '\n' 的长度是4个字符
    [.."\\r", '\'', .. rest_str] => (Constant(Char('\r')), rest_str, 4) // '\r' 的长度是4个字符
    [.."\\t", '\'', .. rest_str] => (Constant(Char('\t')), rest_str, 4) // '\t' 的长度是4个字符
    [.."\\\'", '\'', .. rest_str] => (Constant(Char('\'')), rest_str, 4) // '\'' 的长度是4个字符
    [c, '\'', .. rest_str] => (Constant(Char(c)), rest_str, 3) // 'c' 的长度是3个字符
    ['\'', ..] => raise LexerError("Empty char literal")
    code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
  }
}

// @strconv.parse_int: (String, Int) -> Int, input is string and base, return an int
// @strconv.parse_int64: (String, Int) -> Int64, input is string and base, return an int
// @strconv.parse_double: (String, Int) -> Double, input is string and base, return an int
fn lex_number(code: @string.View) -> (Token, @string.View, Int) raise {
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
  (Constant(num), rest, numstr.length())
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
  "typeof" : Typeof,
  "__thread" : Thread,
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
  "__restrict__" : Restrict,
  "__restrict" : Restrict,
  "_Atomic" : Atomic,
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

fn lex_ident(code: @string.View) -> (Token, @string.View, Int) {
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
  (tok, rest_str, ident.length())
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
  assert_eq(ctx.alltoks.length(), ctx.tokinfos.length(), msg="Tokenization length mismatch")
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
  assert_eq(ctx.alltoks.length(), ctx.tokinfos.length(), msg="Tokenization length mismatch")
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
