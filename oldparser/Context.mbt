// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
using @env {type Env}

///|
pub struct TokenInfo {
  lineno : Int
  column : Int
  codeidx : Int
  source_file : String
}

///|
pub struct ParserContext {
  source_file : String
  code : String
  mut alltoks : Array[Token]
  mut tokinfos : Array[TokenInfo]
  mut typedefs : Env[Int]
  external_decls : Array[ExternalDeclaration]
}

///|
pub enum WarningError {
  Warning
  Error
}

///|
pub fn ParserContext::print_toks(self : ParserContext) -> Unit {
  let str_builder = StringBuilder::new()
  str_builder.write_char('[')
  let toklen = self.alltoks.length()
  for i in 0..<(toklen - 1) {
    str_builder.write_string("\{self.alltoks[i]}, ")
  }
  if toklen > 0 {
    str_builder.write_string("\{self.alltoks[toklen-1]}")
  }
  str_builder.write_char(']')
  let str = str_builder.to_string()
  println(str)
}

///|
pub fn ParserContext::print_ast(self : ParserContext) -> Unit {
  for d in self.external_decls {
    println(d)
  }
}

///|
fn ParserContext::get_error_or_warning_msg(
  self : Self,
  idx : Int,
  msg : String,
  we : WarningError,
) -> String {
  let color = match we {
    Warning => @color.Yellow
    Error => @color.Red
  }
  if idx < 0 || idx >= self.tokinfos.length() {
    return ""
  }
  let tokinfo = self.tokinfos[idx]
  let lineno = tokinfo.lineno
  let column = tokinfo.column
  let codeidx = tokinfo.codeidx
  let source_file = tokinfo.source_file
  let str_builder = StringBuilder::new()

  // 第一行：文件名、行号和列号
  let head_line = @color.taint(
    "[\{source_file}:\{lineno}:\{column}] Warning:",
    @color.Magenta,
  )
  str_builder.write_string("\{head_line}\n")

  // 第二行：空行
  str_builder.write_string("\{lineno-1}|\n")

  // 第三行：找到包含当前token的代码行
  let code_line = self.get_code_line(codeidx)
  str_builder.write_string("\{lineno}|  \{code_line}\n")

  // 第四行：在column位置打印`^`，然后打印msg
  let mut indent = "  " // 与代码行的缩进保持一致
  for _ in 1..<column {
    indent += " "
  }
  let msg = @color.taint("^ \{msg}", color)
  str_builder.write_string("\{lineno+1}|\{indent}\{msg}\n")
  str_builder.to_string()
}

///|
pub fn ParserContext::get_warning_msg(
  self : Self,
  idx : Int,
  msg : String,
) -> String {
  self.get_error_or_warning_msg(idx, msg, Warning)
}

///|
pub fn ParserContext::get_error_msg(
  self : Self,
  idx : Int,
  msg : String,
) -> String {
  self.get_error_or_warning_msg(idx, msg, Error)
}

// 辅助函数：根据codeidx获取对应的代码行

///|
fn ParserContext::get_code_line(self : Self, codeidx : Int) -> String {
  let code = self.code
  let len = code.length()

  // 如果codeidx超出范围，返回空字符串
  if codeidx >= len {
    return ""
  }

  // 向前找到行的开始（第一个换行符，如果不是第一行）
  let mut line_start = 0
  let mut i = codeidx - 1
  while i >= 0 {
    if code[i] == '\n' {
      line_start = i + 1
      break
    }
    i = i - 1
  }

  // 向后找到行的结束（下一个换行符）
  let mut line_end = len
  i = codeidx
  while i < len {
    if code[i] == '\n' {
      line_end = i
      break
    }
    i = i + 1
  }

  // 提取代码行
  if line_start < line_end {
    let s = try! code[line_start:line_end]
    s.to_string()
  } else {
    ""
  }
}

///|
fn ParserContext::add_typedef(self : ParserContext, name : String) -> Unit {
  self.typedefs.set(name, 1)
}

///|
fn ParserContext::enter_scope(self : ParserContext) -> Unit {
  let curr_scope = self.typedefs
  self.typedefs = Env::new()
  self.typedefs.parent = Some(curr_scope)
}

///|
fn ParserContext::leave_scope(self : ParserContext) -> Unit {
  match self.typedefs.parent {
    Some(parent) => self.typedefs = parent
    None => ()
  }
}

///|
pub fn ParserContext::create_by_code(code : String) -> ParserContext {
  let ctx = ParserContext::{
    source_file: "demo",
    code,
    alltoks: Array::new(),
    tokinfos: Array::new(),
    typedefs: Env::new(),
    external_decls: Array::new(),
  }

  // builtin typedefs
  ctx.add_typedef("__builtin_va_list")
  ctx
}

///|
pub fn ParserContext::create_by_file(file_path : String) -> ParserContext {
  let path = @path.Path::new(file_path)
  if !path.is_exists() {
    println("File not found: \{file_path}")
    panic()
  }
  if !path.is_file() {
    println("Not a file: \{file_path}")
    panic()
  }
  let path_str = path.to_absolute()
  let code = @fs.read_file_to_string(path_str) catch {
    _ => {
      println("Failed to read file: \{path_str}")
      panic()
    }
  }
  let ctx = ParserContext::{
    source_file: path_str,
    code,
    alltoks: Array::new(),
    tokinfos: Array::new(),
    typedefs: Env::new(),
    external_decls: Array::new(),
  }
  // builtin typedefs
  ctx.add_typedef("__builtin_va_list")
  ctx
}

//pub fn ParserContext::create_by_path(file_path: String) -> ParserContext {
//  // split file_path into directory and filename
//  let path = 
//}

//fn ParserContext::is_typedef(self: ParserContext, name: String) -> Bool {
//  self.typedefs.contains(name)
//}

///|
fn ParserContext::is_declspec_tok(self : ParserContext, tok : Token) -> Bool {
  match tok {
    Void
    | Bool
    | Char
    | Short
    | Int
    | Long
    | Struct
    | Union
    | Typedef
    | Enum
    | Static
    | Extern
    | Alignas
    | Signed
    | Unsigned
    | Const
    | Volatile
    | Auto
    | Register
    | Restrict
    | Noreturn
    | Float
    | Double
    | Typeof
    | Inline
    | ThreadLocal
    | Atomic => true
    Identifier(name) =>
      // Check if the identifier is a typedef
      //self.typedefs.contains(name)
      //self.get_typedef(name) is Some(_)
      self.typedefs.contains(name)
    _ => false
  }
}

//test "print_warning test" {
//  let code = 
//    #|int main() {
//    #|  int x = 5;
//    #|  return x;
//    #|}
//
//  let ctx = ParserContext::create(code, source_file="test.c")
//  ctx.tokenize()
//
//  // 演示不同位置的警告
//  println("=== Print Warning Demo ===")
//
//  // 第一行的关键字
//  println(ctx.get_warning_msg(0, "This is a test warning for 'int' keyword"))
//
//  // 第一行的标识符
//  println(ctx.get_warning_msg(1, "This is a test warning for 'main' identifier"))
//
//
//  // 第二行的变量
//  println(ctx.get_error_msg(6, "This is a test warning for variable 'x'"))
//
//  println("=== End Demo ===")
//}
