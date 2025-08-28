///|
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
  Bool // _Bool
  Complex // _Complex
  Imaginary // _Imaginary
  Auto
  Register
  Static
  Extern
  Typedef
  Thread
  ThreadLocal // _Thread_local
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
  Alignas // _Alignas
  Alignof // _Alignof
  StaticAssert // _Static_assert
  Generic
  Attribute // __attribute__
  BuiltinOffsetof // __builtin_offsetof

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
  Mod // %
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

///|
fn Token::is_assign_op(tok : Token) -> Bool {
  match tok {
    Assign
    | PlusAssign
    | MinusAssign
    | StarAssign
    | DivAssign
    | ModAssign
    | LeftShiftAssign
    | RightShiftAssign
    | AndAssign
    | OrAssign
    | BitXorAssign
    | BitAndAssign
    | BitOrAssign => true
    _ => false
  }
}

///|
pub enum Constant {
  Int(Int)
  Long(Int64)
  UInt(UInt)
  ULong(UInt64)
  Float(Float)
  Double(Double)
  Char(Char)
} derive(Show, Eq)

///|
pub suberror LexerError String derive(Show)

///|
pub fn ParserContext::tokenize(self : Self) -> Unit raise {
  let tokens = self.alltoks
  let tokinfos = self.tokinfos
  let mut lineno = 1
  let mut column = 1
  let mut codeidx = 0
  loop self.code[:] {
    [] => {
      tokens.push(EOF)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      break
    }
    ['\n', .. rest] => {
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
    [.. "//", .. rest] => {
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
    [.. "/*", .. rest] => {
      codeidx += 2 // "/*" 占2个字符
      column += 2
      continue loop rest {
          [.. "*/", .. rest_str] => {
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
    [.. "<<=", .. rest] => {
      tokens.push(LeftShiftAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 3
      codeidx += 3
      continue rest
    }
    [.. ">>=", .. rest] => {
      tokens.push(RightShiftAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 3
      codeidx += 3
      continue rest
    }
    [.. "&&=", .. rest] => {
      tokens.push(AndAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 3
      codeidx += 3
      continue rest
    }
    [.. "||=", .. rest] => {
      tokens.push(OrAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 3
      codeidx += 3
      continue rest
    }
    [.. "<<", .. rest] => {
      tokens.push(Shl)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. ">>", .. rest] => {
      tokens.push(Shr)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "++", .. rest] => {
      tokens.push(PlusPlus)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "--", .. rest] => {
      tokens.push(MinusMinus)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "->", .. rest] => {
      tokens.push(Arrow)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "...", .. rest] => {
      tokens.push(Ellipsis)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 3
      codeidx += 3
      continue rest
    }
    [.. "==", .. rest] => {
      tokens.push(EQ)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "!=", .. rest] => {
      tokens.push(NE)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "<=", .. rest] => {
      tokens.push(LE)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "<", .. rest] => {
      tokens.push(LT)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [.. ">=", .. rest] => {
      tokens.push(GE)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. ">", .. rest] => {
      tokens.push(GT)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [.. "&&", .. rest] => {
      tokens.push(DoubleAnd)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "||", .. rest] => {
      tokens.push(DoubleOr)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "*=", .. rest] => {
      tokens.push(StarAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "/=", .. rest] => {
      tokens.push(DivAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "%=", .. rest] => {
      tokens.push(ModAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "+=", .. rest] => {
      tokens.push(PlusAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "-=", .. rest] => {
      tokens.push(MinusAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "&=", .. rest] => {
      tokens.push(BitAndAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "^=", .. rest] => {
      tokens.push(BitXorAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    [.. "|=", .. rest] => {
      tokens.push(BitOrAssign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 2
      codeidx += 2
      continue rest
    }
    ['(', .. rest] => {
      tokens.push(LParen)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [')', .. rest] => {
      tokens.push(RParen)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['[', .. rest] => {
      tokens.push(LBracket)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [']', .. rest] => {
      tokens.push(RBracket)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['{', .. rest] => {
      tokens.push(LBrace)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['}', .. rest] => {
      tokens.push(RBrace)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [';', .. rest] => {
      tokens.push(Semi)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [':', .. rest] => {
      tokens.push(Colon)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['.', '0'..='9', ..] as code => {
      // 这是一个以 . 开头的浮点数
      let tokinfo = TokenInfo::{ lineno, column, codeidx }
      let (tok, rest, char_count) = lex_number(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    ['.', .. rest] => {
      tokens.push(Dot)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    [',', .. rest] => {
      tokens.push(Comma)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['+', .. rest] => {
      tokens.push(Plus)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['-', .. rest] => {
      tokens.push(Minus)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['*', .. rest] => {
      tokens.push(Star)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['/', .. rest] => {
      tokens.push(Slash)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['%', .. rest] => {
      tokens.push(Mod)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['&', .. rest] => {
      tokens.push(And)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['|', .. rest] => {
      tokens.push(Or)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['^', .. rest] => {
      tokens.push(Xor)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['!', .. rest] => {
      tokens.push(Not)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['?', .. rest] => {
      tokens.push(Question)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['~', .. rest] => {
      tokens.push(Tilde)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['=', .. rest] => {
      tokens.push(Assign)
      tokinfos.push(TokenInfo::{ lineno, column, codeidx })
      column += 1
      codeidx += 1
      continue rest
    }
    ['\'', ..] as code => {
      let tokinfo = TokenInfo::{ lineno, column, codeidx }
      let (tok, rest, char_count) = lex_char_literal(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    //['\'', ..] as code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
    ['"', ..] as code => {
      let tokinfo = TokenInfo::{ lineno, column, codeidx }
      let (tok, rest, char_count) = lex_string_literal(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    ['0'..='9', ..] as code => {
      let tokinfo = TokenInfo::{ lineno, column, codeidx }
      let (tok, rest, char_count) = lex_number(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    ['a'..='z' | 'A'..='Z' | '_' | '$', ..] as code => {
      let tokinfo = TokenInfo::{ lineno, column, codeidx }
      let (tok, rest, char_count) = lex_ident(code)
      tokens.push(tok)
      tokinfos.push(tokinfo)
      column += char_count
      codeidx += char_count
      continue rest
    }
    code =>
      raise LexerError(
        "Parse Error: Unexpected char: \{code[0]}, loc = \{code.start_offset()}",
      )
  }
}

///|
fn lex_string_literal(code : @string.View) -> (Token, @string.View, Int) raise {
  guard code is ['"', .. code]  // skip first '"'
  let str = Array::new()
  let mut char_count = 1 // 开始的引号
  let rest = loop code {
    ['"', .. rest_str] => {
      char_count += 1 // 结束的引号
      break rest_str
    }
    [.. "\\n", .. rest_str] => {
      str.push('\n')
      char_count += 2 // \n 是2个字符
      continue rest_str
    }
    [.. "\\r", .. rest_str] => {
      str.push('\r')
      char_count += 2 // \r 是2个字符
      continue rest_str
    }
    [.. "\\t", .. rest_str] => {
      str.push('\t')
      char_count += 2 // \t 是2个字符
      continue rest_str
    }
    [.. "\\\"", .. rest_str] => {
      str.push('"')
      char_count += 2 // \" 是2个字符
      continue rest_str
    }
    [.. "\\\\", .. rest_str] => {
      str.push('\\')
      char_count += 2 // \\ 是2个字符
      continue rest_str
    }
    ['\n', ..] =>
      raise LexerError("Parse Error: Unclosed string literal, found newline")
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

///|
fn lex_char_literal(code : @string.View) -> (Token, @string.View, Int) raise {
  guard code is ['\'', .. code]
  match code {
    [.. "\\n", '\'', .. rest_str] => (Constant(Char('\n')), rest_str, 4) // '\n' 的长度是4个字符
    [.. "\\r", '\'', .. rest_str] => (Constant(Char('\r')), rest_str, 4) // '\r' 的长度是4个字符
    [.. "\\t", '\'', .. rest_str] => (Constant(Char('\t')), rest_str, 4) // '\t' 的长度是4个字符
    [.. "\\\'", '\'', .. rest_str] => (Constant(Char('\'')), rest_str, 4) // '\'' 的长度是4个字符
    [c, '\'', .. rest_str] => (Constant(Char(c)), rest_str, 3) // 'c' 的长度是3个字符
    ['\'', ..] => raise LexerError("Empty char literal")
    code => raise LexerError("Parse Error: Unclosed char literal: \{code}")
  }
}

// 解析十六进制浮点数 (如 1.921fb54442d18p+2)

///|
fn parse_hex_float(hex_str : String) -> Double {
  // 十六进制浮点数格式: [整数部分].[小数部分]p[指数]
  // 例如: 1.921fb54442d18p+2
  // 这相当于 (1 + 0x921fb54442d18 / 16^13) * 2^2

  let mut mantissa = 0.0
  let mut exponent = 0
  let mut i = 0
  let len = hex_str.length()

  // 跳过可能的 "0x" 前缀
  if i + 1 < len &&
    hex_str[i] == 48 &&
    (hex_str[i + 1] == 120 || hex_str[i + 1] == 88) { // '0' = 48, 'x' = 120, 'X' = 88
    i += 2
  }

  // 解析整数部分
  while i < len && hex_char_value_from_int(hex_str[i]) is Some(digit) {
    mantissa = mantissa * 16.0 + digit.to_double()
    i += 1
  }

  // 解析小数部分
  if i < len && hex_str[i] == 46 { // '.' = 46
    i += 1
    let mut fraction_power = 1.0
    while i < len && hex_char_value_from_int(hex_str[i]) is Some(digit) {
      fraction_power /= 16.0
      mantissa += digit.to_double() * fraction_power
      i += 1
    }
  }

  // 解析指数部分
  if i < len && (hex_str[i] == 112 || hex_str[i] == 80) { // 'p' = 112, 'P' = 80
    i += 1
    let mut exp_sign = 1
    if i < len && hex_str[i] == 43 { // '+' = 43
      i += 1
    } else if i < len && hex_str[i] == 45 { // '-' = 45
      exp_sign = -1
      i += 1
    }
    while i < len && hex_str[i] >= 48 && hex_str[i] <= 57 { // '0' = 48, '9' = 57
      exponent = exponent * 10 + (hex_str[i] - 48)
      i += 1
    }
    exponent *= exp_sign
  }

  // 计算最终值: mantissa * 2^exponent
  let result = mantissa * @math.pow(2.0, exponent.to_double())
  result
}

// 辅助函数：将十六进制字符的整数值转换为数字值

///|
fn hex_char_value_from_int(char_code : Int) -> Int? {
  match char_code {
    48 => Some(0) // '0'
    49 => Some(1) // '1'
    50 => Some(2) // '2'
    51 => Some(3) // '3'
    52 => Some(4) // '4'
    53 => Some(5) // '5'
    54 => Some(6) // '6'
    55 => Some(7) // '7'
    56 => Some(8) // '8'
    57 => Some(9) // '9'
    97 | 65 => Some(10) // 'a' | 'A'
    98 | 66 => Some(11) // 'b' | 'B'
    99 | 67 => Some(12) // 'c' | 'C'
    100 | 68 => Some(13) // 'd' | 'D'
    101 | 69 => Some(14) // 'e' | 'E'
    102 | 70 => Some(15) // 'f' | 'F'
    _ => None
  }
}

// @strconv.parse_int: (String, Int) -> Int, input is string and base, return an int
// @strconv.parse_int64: (String, Int) -> Int64, input is string and base, return an int
// @strconv.parse_double: (String, Int) -> Double, input is string and base, return an int

///|
fn lex_number(code : @string.View) -> (Token, @string.View, Int) raise {
  match code {
    // 十六进制数字 (0x 或 0X 开头)
    [.. "0x", ..] | [.. "0X", ..] => lex_hex_number(code)
    ['0', '0'..='7', ..] => lex_octal_number(code)
    ['0', '8' | '9', ..] => lex_decimal_number(code) // 八进制数字后面跟了 8 或 9，作为十进制处理
    // 单独的 0
    ['0'] => lex_octal_number(code)
    // 以小数点开始的浮点数
    ['.', '0'..='9', ..] => lex_decimal_number(code)
    // 十进制数字或浮点数
    _ => lex_decimal_number(code)
  }
}

// 解析十六进制数字（可能是整数或浮点数）

///|
fn lex_hex_number(code : @string.View) -> (Token, @string.View, Int) raise {
  let hex_digits = Array::new()
  let mut char_count = 2 // "0x" 或 "0X"
  let mut has_dot = false
  let mut has_p_exp = false
  let rest = match code {
    [.. "0x", .. rest] | [.. "0X", .. rest] => {
      // 读取整数部分
      let mut rest = loop rest {
        ['0'..='9' | 'a'..='f' | 'A'..='F' as c, .. rest_str] => {
          hex_digits.push(c)
          char_count += 1
          continue rest_str
        }
        _ as rest_str => break rest_str
      }

      // 检查小数点
      rest = match rest {
        ['.', .. dot_rest] => {
          has_dot = true
          hex_digits.push('.')
          char_count += 1
          // 读取小数点后的十六进制数字
          loop dot_rest {
            ['0'..='9' | 'a'..='f' | 'A'..='F' as c, .. rest_str] => {
              hex_digits.push(c)
              char_count += 1
              continue rest_str
            }
            _ as rest_str => break rest_str
          }
        }
        _ => rest
      }

      // 检查二进制指数部分 (p 或 P)
      rest = match rest {
        ['p' | 'P' as p, .. exp_rest] => {
          has_p_exp = true
          hex_digits.push(p)
          char_count += 1

          // 检查正负号
          let exp_rest = match exp_rest {
            ['+' | '-' as sign, .. sign_rest] => {
              hex_digits.push(sign)
              char_count += 1
              sign_rest
            }
            _ => exp_rest
          }

          // 读取指数数字（十进制）
          loop exp_rest {
            ['0'..='9' as c, .. rest_str] => {
              hex_digits.push(c)
              char_count += 1
              continue rest_str
            }
            _ as rest_str => break rest_str
          }
        }
        _ => rest
      }
      rest
    }
    _ => raise LexerError("Invalid hex number")
  }
  if hex_digits.is_empty() {
    raise LexerError("Invalid hex number: no digits after 0x")
  }
  let hex_str = String::from_array(hex_digits)

  // 十六进制浮点数必须有小数点或指数
  if has_dot || has_p_exp {
    // 这是十六进制浮点数
    let (suffix, rest, suffix_len) = parse_float_suffix(rest)
    char_count += suffix_len

    // 解析十六进制浮点数
    let num = parse_hex_float(hex_str)
    let token = match suffix.to_lower() {
      "f" => Token::Constant(Constant::Float(num.to_float()))
      _ => Token::Constant(Constant::Double(num))
    }
    (token, rest, char_count)
  } else {
    // 这是十六进制整数
    let (suffix, rest, suffix_len) = parse_integer_suffix(rest)
    char_count += suffix_len
    let num = @strconv.parse_uint64(hex_str, base=16) catch {
      err => {
        println("Error parsing hex number: \{err}")
        raise err
      }
    }
    let token = match suffix {
      // 对于带 U 后缀的，我们仍然用 Long 类型表示但标记为无符号
      "ul" | "UL" | "uL" | "Ul" | "lu" | "LU" | "lU" | "Lu" =>
        Token::Constant(Constant::ULong(num))
      "ULL" | "ull" | "Ull" | "uLL" => Token::Constant(Constant::ULong(num))
      "LL" | "ll" => Token::Constant(Constant::Long(num.reinterpret_as_int64()))
      "l" | "L" => Token::Constant(Constant::Long(num.reinterpret_as_int64()))
      "u" | "U" =>
        if num >= 0 && num <= 4294967295UL {
          Token::Constant(Constant::UInt(num.to_uint()))
        } else {
          raise LexerError("Invalid unsigned integer: \{hex_str}")
        }
      "" =>
        // 根据数值大小决定类型
        if num >= 0 && num <= 2147483647UL {
          Token::Constant(Constant::Int(num.to_int()))
        } else {
          Token::Constant(Constant::Long(num.reinterpret_as_int64()))
        }
      _ => raise LexerError("Invalid integer suffix: \{suffix}")
    }
    (token, rest, char_count)
  }
}

// 解析八进制数字

///|
fn lex_octal_number(code : @string.View) -> (Token, @string.View, Int) raise {
  let octal_digits = Array::new()
  let mut char_count = 0
  let rest = loop code {
    ['0'..='7' as c, .. rest_str] => {
      octal_digits.push(c)
      char_count += 1
      continue rest_str
    }
    _ as rest_str => break rest_str
  }
  let octal_str = String::from_array(octal_digits)

  // 检查后缀
  let (suffix, rest, suffix_len) = parse_integer_suffix(rest)
  char_count += suffix_len
  let num = @strconv.parse_uint64(octal_str, base=8) catch {
    err => {
      println("Error parsing oct number: \{err}")
      raise err
    }
  }
  let token = match suffix {
    "ul" | "UL" | "uL" | "Ul" | "lu" | "LU" | "lU" | "Lu" =>
      Token::Constant(Constant::ULong(num))
    "ULL" | "ull" | "Ull" | "uLL" => Token::Constant(Constant::ULong(num))
    "l" | "L" => Token::Constant(Constant::Long(num.reinterpret_as_int64()))
    "LL" | "ll" => Token::Constant(Constant::Long(num.reinterpret_as_int64()))
    "u" | "U" =>
      if num >= 0 && num <= 4294967295UL {
        Token::Constant(Constant::UInt(num.to_uint()))
      } else {
        raise LexerError("Invalid unsigned integer: \{octal_str}")
      }
    "" =>
      if num >= 0 && num <= 2147483647UL {
        Token::Constant(Constant::Int(num.to_int()))
      } else {
        Token::Constant(Constant::Long(num.reinterpret_as_int64()))
      }
    _ => raise LexerError("Invalid integer suffix: \{suffix}")
  }
  (token, rest, char_count)
}

// 解析十进制数字（可能是整数或浮点数）

///|
fn lex_decimal_number(code : @string.View) -> (Token, @string.View, Int) raise {
  let digits = Array::new()
  let mut char_count = 0
  let mut has_dot = false
  let mut has_exp = false

  // 读取整数部分
  let mut rest = loop code {
    ['0'..='9' as c, .. rest_str] => {
      digits.push(c)
      char_count += 1
      continue rest_str
    }
    _ as rest_str => break rest_str
  }

  // 检查小数点
  rest = match rest {
    ['.', .. dot_rest] => {
      has_dot = true
      digits.push('.')
      char_count += 1
      // 读取小数点后的数字（可能没有）
      loop dot_rest {
        ['0'..='9' as c, .. rest_str] => {
          digits.push(c)
          char_count += 1
          continue rest_str
        }
        _ as rest_str => break rest_str
      }
    }
    _ => rest
  }

  // 检查指数部分
  rest = match rest {
    ['e' | 'E' as e, .. exp_rest] => {
      has_exp = true
      digits.push(e)
      char_count += 1

      // 检查正负号
      let exp_rest = match exp_rest {
        ['+' | '-' as sign, .. sign_rest] => {
          digits.push(sign)
          char_count += 1
          sign_rest
        }
        _ => exp_rest
      }

      // 读取指数数字
      loop exp_rest {
        ['0'..='9' as c, .. rest_str] => {
          digits.push(c)
          char_count += 1
          continue rest_str
        }
        _ as rest_str => break rest_str
      }
    }
    _ => rest
  }
  let num_str = String::from_array(digits)
  if has_dot || has_exp {
    // 浮点数
    let (suffix, rest, suffix_len) = parse_float_suffix(rest)
    char_count += suffix_len
    let num = @strconv.parse_double(num_str) catch {
      err => {
        println("Error parsing decimal number: \{num_str}")
        raise err
      }
    }
    let token = match suffix.to_lower() {
      "f" => Token::Constant(Constant::Float(num.to_float()))
      _ => Token::Constant(Constant::Double(num))
    }
    (token, rest, char_count)
  } else {
    // 整数
    let (suffix, rest, suffix_len) = parse_integer_suffix(rest)
    char_count += suffix_len
    let num = @strconv.parse_uint64(num_str, base=10) catch {
      err => {
        println("Error parsing decimal number: \{err}")
        raise err
      }
    }
    let token = match suffix {
      "ul"
      | "UL"
      | "uL"
      | "Ul"
      | "lu"
      | "LU"
      | "lU"
      | "Lu"
      | "ULL"
      | "ull"
      | "Ull"
      | "uLL" => Token::Constant(Constant::ULong(num))
      "l" | "L" => Token::Constant(Constant::Long(num.reinterpret_as_int64()))
      "LL" | "ll" => Token::Constant(Constant::Long(num.reinterpret_as_int64()))
      "u" | "U" =>
        if num >= 0 && num <= 4294967295UL {
          Token::Constant(Constant::UInt(num.to_uint()))
        } else {
          raise LexerError("Invalid unsigned integer: \{num_str}")
        }
      "" =>
        if num >= 0 && num <= 2147483647UL {
          Token::Constant(Constant::Int(num.to_int()))
        } else {
          Token::Constant(Constant::Long(num.reinterpret_as_int64()))
        }
      suffix => raise LexerError("Invalid integer suffix: \{suffix}")
    }
    (token, rest, char_count)
  }
}

// 解析整数后缀 (u, l, ul, etc.)

///|
fn parse_integer_suffix(code : @string.View) -> (String, @string.View, Int) {
  match code {
    [.. "LL", .. rest] => ("LL", rest, 2)
    [.. "ll", .. rest] => ("ll", rest, 2)
    [.. "ULL", .. rest] => ("ULL", rest, 3)
    [.. "Ull", .. rest] => ("Ull", rest, 3)
    [.. "ull", .. rest] => ("ull", rest, 3)
    [.. "uLL", .. rest] => ("uLL", rest, 3)
    ['u' | 'U' as c1, 'l' | 'L' as c2, .. rest] =>
      (String::from_array([c1, c2]), rest, 2)
    ['l' | 'L' as c1, 'u' | 'U' as c2, .. rest] =>
      (String::from_array([c1, c2]), rest, 2)
    ['u' | 'U' as c, .. rest] => (String::from_array([c]), rest, 1)
    ['l' | 'L' as c, .. rest] => (String::from_array([c]), rest, 1)
    _ => ("", code, 0)
  }
}

// 解析浮点数后缀 (f, l)

///|
fn parse_float_suffix(code : @string.View) -> (String, @string.View, Int) {
  match code {
    ['f' | 'F' | 'l' | 'L' as c, .. rest] => (String::from_array([c]), rest, 1)
    _ => ("", code, 0)
  }
}

///|
let keywords : Map[String, Token] = {
  "void": Void,
  "char": Char,
  "short": Short,
  "int": Int,
  "long": Long,
  "float": Float,
  "double": Double,
  "signed": Signed,
  "unsigned": Unsigned,
  "_Bool": Bool,
  "_Complex": Complex,
  "_Imaginary": Imaginary,
  "auto": Auto,
  "register": Register,
  "static": Static,
  "extern": Extern,
  "typedef": Typedef,
  "typeof": Typeof,
  "__thread": Thread,
  "_Thread_local": ThreadLocal,
  "if": If,
  "else": Else,
  "switch": Switch,
  "case": Case,
  "default": Default,
  "for": For,
  "while": While,
  "do": Do,
  "goto": Goto,
  "break": Break,
  "continue": Continue,
  "return": Return,
  "const": Const,
  "volatile": Volatile,
  "restrict": Restrict,
  "__restrict__": Restrict,
  "__restrict": Restrict,
  "_Atomic": Atomic,
  "atomic": Atomic,
  "inline": Inline,
  "__inline__": Inline, // GNU extension
  "_Noreturn": Noreturn,
  "struct": Struct,
  "union": Union,
  "enum": Enum,
  "sizeof": Sizeof,
  "_Alignas": Alignas,
  "_Alignof": Alignof,
  "_Static_assert": StaticAssert,
  "_Generic": Generic,
  "__attribute__": Attribute,
  "__builtin_offsetof": BuiltinOffsetof,
}

///|
fn lex_ident(code : @string.View) -> (Token, @string.View, Int) {
  let ident = Array::new()
  let rest_str = loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' as c, .. rest_str] => {
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

///|
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
    Int,
    Void,
    Char,
    Short,
    Long,
    Float,
    Double,
    Signed,
    Unsigned,
    Bool,
    Complex,
    Imaginary,
    Auto,
    Register,
    Static,
    Extern,
    Typedef,
    ThreadLocal,
    If,
    Else,
    Switch,
    Case,
    Default,
    For,
    While,
    Do,
    Goto,
    Break,
    Continue,
    Return,
    Const,
    Volatile,
    Restrict,
    Atomic,
    Inline,
    Noreturn,
    Struct,
    Union,
    Enum,
    Sizeof,
    Alignas,
    Alignof,
    StaticAssert,
    Generic,
    LParen,
    RParen,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
    Plus,
    Minus,
    Star,
    Slash,
    Mod,
    Shr,
    Shl,
    PlusPlus,
    MinusMinus,
    Arrow,
    LT,
    GT,
    GE,
    LE,
    EQ,
    NE,
    Assign,
    StarAssign,
    DivAssign,
    ModAssign,
    PlusAssign,
    MinusAssign,
    LeftShiftAssign,
    RightShiftAssign,
    AndAssign,
    OrAssign,
    BitAndAssign,
    BitXorAssign,
    BitOrAssign,
    And,
    Or,
    Not,
    Xor,
    Tilde,
    DoubleAnd,
    DoubleOr,
    Comma,
    Dot,
    Colon,
    Semi,
    Question,
    Ellipsis,
    StringLiteral("hello, world"),
    StringLiteral("hello\n"),
    StringLiteral("hello\r"),
    StringLiteral("hello\t"),
    StringLiteral("\"hello\""),
    StringLiteral("hello\\"),
    Constant(Char('c')),
    Constant(Char('\n')),
    Constant(Char('\r')),
    Constant(Char('\t')),
    Constant(Char('\'')),
    Constant(Char('"')),
    Constant(Int(123)),
    Identifier("xyz"),
    Identifier("a123"),
    EOF,
  ]
  let ctx = ParserContext::create(code)
  ctx.tokenize()
  assert_eq(
    ctx.alltoks.length(),
    ctx.tokinfos.length(),
    msg="Tokenization length mismatch",
  )
  for i in 0..<expect.length() {
    assert_eq(
      ctx.alltoks.get(i),
      Some(expect[i]),
      msg="Tokenization Test Failed at index \{i}, expect \{expect[i]} got \{ctx.alltoks[i]}",
    )
  }
}

///|
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
    Int,
    Void,
    Char,
    Short,
    Constant(Int(123)),
    Unsigned,
    Comma,
    EOF,
  ]
  let ctx = ParserContext::create(code)
  ctx.tokenize()
  assert_eq(
    ctx.alltoks.length(),
    ctx.tokinfos.length(),
    msg="Tokenization length mismatch",
  )
  for i in 0..<expect.length() {
    assert_eq(
      ctx.alltoks.get(i),
      Some(expect[i]),
      msg="Tokenization Test Failed at index \{i}, expect \{expect[i]} got \{ctx.alltoks[i]}",
    )
  }
}

///|
test "tokenize error test" {
  let code = "\"hello"
  let ctx = ParserContext::create(code)
  assert_true(
    (try? ctx.tokenize()) is Err(_),
    msg="Tokenization should fail for unclosed string literal",
  )
  let code = "'c"
  let ctx = ParserContext::create(code)
  assert_true(
    (try? ctx.tokenize()) is Err(_),
    msg="Tokenization should fail for unclosed char literal",
  )
  let code = "''"
  let ctx = ParserContext::create(code)
  assert_true(
    (try? ctx.tokenize()) is Err(_),
    msg="Tokenization should fail for empty char literal",
  )
  let code =
    #|"hello
    #|
  let ctx = ParserContext::create(code)
  assert_true(
    (try? ctx.tokenize()) is Err(_),
    msg="Tokenization should fail for unclosed string literal",
  )
  let code = "中"
  let ctx = ParserContext::create(code)
  assert_true(
    (try? ctx.tokenize()) is Err(_),
    msg="Tokenization should fail for non-ASCII character",
  )
}

///|
test "tokenize numbers test" {
  let code =
    #|123 456L 789U 012UL 4294967295UL
    #|0x123 0xFF 0xABCDEF 0x123L 0x456U 0x789UL
    #|0123 0777 0123L 0456U 0777UL
    #|3.14 2.5f 1.0L 6.02e23 1.5e-10 2.0E+5
    #|.5 5. 1e10 2E-5 .1 0 0x0 0UL 0L 0U 
  let expect : Array[Token] = [
    Constant(Int(123)),
    Constant(Long(456L)),
    Constant(UInt(789U)), // U 后缀用 Long 表示
    Constant(ULong(10UL)), // 012UL 八进制 = 10
    Constant(ULong(4294967295UL)), // 4294967295UL = 2^32 - 1
    Constant(Int(291)), // 0x123 = 291
    Constant(Int(255)), // 0xFF = 255
    Constant(Int(11259375)), // 0xABCDEF = 11259375
    Constant(Long(291L)), // 0x123L
    Constant(UInt(1110U)), // 0x456U
    Constant(ULong(1929UL)), // 0x789UL

    // 八进制整数
    Constant(Int(83)), // 0123 = 83
    Constant(Int(511)), // 0777 = 511
    Constant(Long(83L)), // 0123L
    Constant(UInt(302U)), // 0456U
    Constant(ULong(511UL)), // 0777UL

    // 浮点数
    Constant(Double(3.14)),
    Constant(Float(2.5)),
    Constant(Double(1.0)),
    Constant(Double(6.02e23)),
    Constant(Double(1.5e-10)),
    Constant(Double(2.0e5)),

    // 特殊浮点数格式
    Constant(Double(0.5)), // .5
    Constant(Double(5.0)), // 5.
    Constant(Double(10000000000.0)), // 1e10
    Constant(Double(0.00002)), // 2E-5
    Constant(Double(0.1)), // .1
    Constant(Int(0)), // 0
    Constant(Int(0)), // 0x0
    Constant(ULong(0UL)), // 0UL
    Constant(Long(0L)), // 0L
    Constant(UInt(0U)), // 0U
    EOF,
  ]
  let ctx = ParserContext::create(code)
  ctx.tokenize()
  assert_eq(
    ctx.alltoks.length(),
    ctx.tokinfos.length(),
    msg="Tokenization length mismatch",
  )
  for i in 0..<expect.length() {
    let expected = expect[i]
    let actual = ctx.alltoks.get(i)
    assert_eq(
      actual,
      Some(expected),
      msg="Number tokenization test failed at index \{i}, expected \{expected} got \{actual}",
    )
  }
}

///|
test "tokenize hex float test" {
  let code =
    #|0x1.921fb54442d18p+2 0x1.158e460913dp+63 0x1.0p+1 0x1.5p-1 0x0.8p+3
  let ctx = ParserContext::create(code)
  ctx.tokenize()

  // 检查tokens的数量 (5个十六进制浮点数 + EOF = 6个tokens)
  assert_eq(
    ctx.alltoks.length(),
    6,
    msg="Should have 6 tokens (5 hex floats + EOF)",
  )

  // 检查所有的tokens都是Double类型的
  for i in 0..<5 {
    match ctx.alltoks.get(i) {
      Some(Constant(Double(_))) => () // 正确
      Some(other) =>
        assert_true(
          false,
          msg="Expected Double constant at index \{i}, got \{other}",
        )
      None => assert_true(false, msg="No token found at index \{i}")
    }
  }

  // 检查最后一个token是EOF
  assert_eq(ctx.alltoks.get(5), Some(EOF), msg="Last token should be EOF")
}

///|
test "parse_hex_float values test" {
  // 测试一些基本的十六进制浮点数值
  // 直接测试几个简单的值

  // 1.0 * 2^0 = 1.0
  let result1 = parse_hex_float("1.0p0")
  assert_true(
    result1 > 0.999 && result1 < 1.001,
    msg="Expected ~1.0 for 1.0p0, got \{result1}",
  )

  // 1.0 * 2^1 = 2.0
  let result2 = parse_hex_float("1.0p1")
  assert_true(
    result2 > 1.999 && result2 < 2.001,
    msg="Expected ~2.0 for 1.0p1, got \{result2}",
  )

  // 1.0 * 2^2 = 4.0
  let result3 = parse_hex_float("1.0p+2")
  assert_true(
    result3 > 3.999 && result3 < 4.001,
    msg="Expected ~4.0 for 1.0p+2, got \{result3}",
  )

  // 1.5 * 2^0 = 1.5 (0x1.8 = 1 + 8/16 = 1.5)
  let result4 = parse_hex_float("1.8p0")
  assert_true(
    result4 > 1.499 && result4 < 1.501,
    msg="Expected ~1.5 for 1.8p0, got \{result4}",
  )
}
