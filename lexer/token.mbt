///|
pub enum Keyword {
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
} derive(Eq)

///|
pub impl Show for Keyword with output(self, logger) {
  match self {
    Void => logger.write_string("void")
    Char => logger.write_string("char")
    Short => logger.write_string("short")
    Int => logger.write_string("int")
    Long => logger.write_string("long")
    Float => logger.write_string("float")
    Double => logger.write_string("double")
    Signed => logger.write_string("signed")
    Unsigned => logger.write_string("unsigned")
    Bool => logger.write_string("_Bool")
    Complex => logger.write_string("_Complex")
    Imaginary => logger.write_string("_Imaginary")
    Auto => logger.write_string("auto")
    Register => logger.write_string("register")
    Static => logger.write_string("static")
    Extern => logger.write_string("extern")
    Typedef => logger.write_string("typedef")
    Thread => logger.write_string("__thread")
    ThreadLocal => logger.write_string("_Thread_local")
    If => logger.write_string("if")
    Else => logger.write_string("else")
    Switch => logger.write_string("switch")
    Case => logger.write_string("case")
    Default => logger.write_string("default")
    For => logger.write_string("for")
    While => logger.write_string("while")
    Do => logger.write_string("do")
    Goto => logger.write_string("goto")
    Break => logger.write_string("break")
    Continue => logger.write_string("continue")
    Return => logger.write_string("return")
    Const => logger.write_string("const")
    Volatile => logger.write_string("volatile")
    Restrict => logger.write_string("restrict")
    Atomic => logger.write_string("atomic")
    Inline => logger.write_string("inline")
    Noreturn => logger.write_string("_Noreturn")
    Struct => logger.write_string("struct")
    Union => logger.write_string("union")
    Enum => logger.write_string("enum")
    Sizeof => logger.write_string("sizeof")
    Typeof => logger.write_string("typeof")
    Alignas => logger.write_string("_Alignas")
    Alignof => logger.write_string("_Alignof")
    StaticAssert => logger.write_string("_Static_assert")
    Generic => logger.write_string("_Generic")
    Attribute => logger.write_string("__attribute__")
    BuiltinOffsetof => logger.write_string("__builtin_offsetof")
  }
}

///|
pub enum TokenKind {
  Keyword(Keyword)

  // Brackets
  Bracket(Char) // (, ), [, ], {, }

  // Operators
  Operator(String)
  AssignOp(String)

  // Symbols
  Comma // ,
  Dot // .
  Arrow // ->
  Colon // :
  Semi // ;
  Ellipsis // ...
  Question // ?
  Identifier(String)
  Int(Int)
  Long(Int64)
  LongLong(Int64)
  UInt(UInt)
  ULong(UInt64)
  ULongLong(UInt64)
  Float(Float)
  Double(Double)
  Char(Char)
  String(String)
  ErrorChar(Char)

  // For Preprocessor
  Hash // #
  Hash2 // ##
  EOF
} derive(Eq)

///|
pub impl Show for TokenKind with output(self, logger) {
  match self {
    Keyword(k) => logger.write_object(k)
    Bracket(c) => logger.write_char(c)
    Operator(op) => logger.write_string(op)
    AssignOp(op) => logger.write_string(op)
    Comma => logger.write_string(",")
    Dot => logger.write_string(".")
    Arrow => logger.write_string("->")
    Colon => logger.write_string(":")
    Semi => logger.write_string(";")
    Ellipsis => logger.write_string("...")
    Question => logger.write_string("?")
    Identifier(name) => logger.write_string(name)
    Int(val) => logger.write_string("\{val}")
    Long(val) => logger.write_string("\{val}l")
    LongLong(val) => logger.write_string("\{val}ll")
    UInt(val) => logger.write_string("\{val}u")
    ULong(val) => logger.write_string("\{val}ul")
    ULongLong(val) => logger.write_string("\{val}ull")
    Float(val) => logger.write_string("\{val}f")
    Double(val) => logger.write_string("\{val}")
    Char(c) => logger.write_char(c)
    String(s) => {
      let inner = s
        .replace_all(old="\\", new="\\\\")
        .replace_all(old="\"", new="\\\"")
        .replace_all(old="\n", new="\\n")
        .replace_all(old="\t", new="\\t")
      logger.write_string("\"\{inner}\"")
    }
    ErrorChar(c) => logger.write_char(c)
    Hash => logger.write_string("#")
    Hash2 => logger.write_string("##")
    EOF => logger.write_string("<EOF>")
  }
}

///|
pub fn TokenKind::detail(self : Self) -> String {
  match self {
    Keyword(k) => "Keyword(\{k})"
    Bracket(c) => "Bracket('\{c}')"
    Operator(op) => "Operator(\"\{op}\")"
    AssignOp(op) => "AssignOp(\"\{op}\")"
    Comma => "Comma"
    Dot => "Dot"
    Arrow => "Arrow"
    Colon => "Colon"
    Semi => "Semi"
    Ellipsis => "Ellipsis"
    Question => "Question"
    Identifier(name) => "Identifier(\"\{name}\")"
    Int(val) => "Int(\{val})"
    Long(val) => "Long(\{val})"
    LongLong(val) => "LongLong(\{val})"
    UInt(val) => "UInt(\{val})"
    ULong(val) => "ULong(\{val})"
    ULongLong(val) => "ULongLong(\{val})"
    Float(val) => "Float(\{val})"
    Double(val) => "Double(\{val})"
    Char(c) => "Char('\{c}')"
    String(s) => "String(\"\{s}\")"
    ErrorChar(c) => "ErrorChar('\{c}')"
    Hash => "Hash"
    Hash2 => "Hash2"
    EOF => "EOF"
  }
}

///|
pub struct Token {
  kind : TokenKind
  source_file : String
  line : Int
  col : Int
  idx : Int
  raw : String
  err_msg : String
}

///|
pub fn dummy_eof() -> Token {
  Token::new(EOF, "", 0, 0, 0, "")
}

///|
pub fn dummy_long(val : Int64, raw? : String = "") -> Token {
  Token::new(Long(val), "", 0, 0, 0, raw)
}

///|
// Create a new token using another token as a location/template.
// This is useful for preprocess-generated tokens (e.g. stringizing).
pub fn token_like(
  template : Token,
  kind : TokenKind,
  raw? : String = "",
  err_msg? : String = "",
) -> Token {
  let { source_file, line, col, idx, .. } = template
  Token::new(kind, source_file, line, col, idx, raw, err_msg~)
}

///|
pub fn string_token_like(template : Token, value : String) -> Token {
  let { source_file, line, col, idx, .. } = template
  Token::new(TokenKind::String(value), source_file, line, col, idx, "")
}

///|
pub impl Show for Token with output(self, logger) {
  logger.write_string(self.detail())
}
//

///|
pub fn Token::detail(self : Self) -> String {
  "Token::{ kind: \{self.kind.detail()}, src: \"\{self.source_file}\", line: \{self.line}, col: \{self.col}, idx: \{self.idx}, raw: \"\{self.raw}\" }"
}

///|
fn Token::new(
  kind : TokenKind,
  source_file : String,
  line : Int,
  col : Int,
  idx : Int,
  raw : String,
  err_msg? : String = "",
) -> Token {
  Token::{ kind, source_file, line, col, idx, raw, err_msg }
}

///|
let keywords : Map[String, Keyword] = {
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
