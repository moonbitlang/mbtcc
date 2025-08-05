struct TokenInfo {
  lineno: Int
  column: Int
  codeidx: Int
}

struct Context {
  source_file: String
  code: String
  alltoks: Array[Token]
  tokinfos: Array[TokenInfo]
  mut typedefs: Env[Int]
}

fn Context::get_warning_msg(self: Self, idx: Int, msg: String) -> String {
  if idx < 0 || idx >= self.tokinfos.length() {return "" }
  let tokinfo = self.tokinfos[idx];
  let lineno = tokinfo.lineno;
  let column = tokinfo.column;
  let codeidx = tokinfo.codeidx;
  let source_file = self.source_file;

  let str_builder = StringBuilder::new();
  
  // 第一行：文件名、行号和列号
  let head_line = @color.taint_magenta("[\{source_file}:\{lineno}:\{column}] Warning:")
  str_builder.write_string("\{head_line}\n")
  
  // 第二行：空行
  str_builder.write_string("#|\n")
  
  // 第三行：找到包含当前token的代码行
  let code_line = self.get_code_line(codeidx)
  str_builder.write_string("#|  \{code_line}\n")

  
  // 第四行：在column位置打印`^`，然后打印msg
  let mut indent = "  " // 与代码行的缩进保持一致
  for _ in 1..<column {
    indent += " "
  }
  let msg = @color.taint_yellow("^ \{msg}")
  str_builder.write_string("#|\{indent}\{msg}\n")
  str_builder.to_string()
}

fn Context::get_error_msg(self: Self, idx: Int, msg: String) -> String {
  if idx < 0 || idx >= self.tokinfos.length() {return "" }
  let tokinfo = self.tokinfos[idx];
  let lineno = tokinfo.lineno;
  let column = tokinfo.column;
  let codeidx = tokinfo.codeidx;
  let source_file = self.source_file;

  let str_builder = StringBuilder::new();
  
  // 第一行：文件名、行号和列号
  let head_line = @color.taint_red("[\{source_file}:\{lineno}:\{column}] Warning:")
  str_builder.write_string("\{head_line}\n")
  
  // 第二行：空行
  str_builder.write_string("#|\n")
  
  // 第三行：找到包含当前token的代码行
  let code_line = self.get_code_line(codeidx)
  str_builder.write_string("#|  \{code_line}\n")

  
  // 第四行：在column位置打印`^`，然后打印msg
  let mut indent = "  " // 与代码行的缩进保持一致
  for _ in 1..<column {
    indent += " "
  }
  let msg = @color.taint_red("^ \{msg}")
  str_builder.write_string("#|\{indent}\{msg}\n\n")
  str_builder.to_string()
}

// 辅助函数：根据codeidx获取对应的代码行
fn Context::get_code_line(self: Self, codeidx: Int) -> String {
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
    code.substring(start=line_start, end=line_end)
  } else {
    ""
  }
}

fn Context::add_typedef(self: Context, name: String) -> Unit {
  self.typedefs.set(name, 1)
}

fn Context::enter_scope(self: Context) -> Unit {
  let curr_scope = self.typedefs;
  self.typedefs = Env::new();
  self.typedefs.parent = Some(curr_scope);
}

fn Context::leave_scope(self: Context) -> Unit {
  match self.typedefs.parent {
    Some(parent) => self.typedefs = parent
    None => ()
  }
}

priv struct Env[V] {
  vars: Map[String, V]
  mut parent: Env[V]?
}

fn[V] Env::new() -> Env[V] {
  Env::{
    vars: Map::new(),
    parent: None
  }
}

fn[V] Env::get(self: Env[V], name: String) -> V? {
  match self.vars.get(name) {
    Some(v) => Some(v)
    None => match self.parent {
      Some(parent) => parent.get(name)
      None => None
    }
  }
}

fn[V] Env::set(self: Env[V], name: String, value: V) -> Unit {
  self.vars.set(name, value)
}

fn[V] Env::contains(self: Env[V], name: String) -> Bool {
  match self.vars.get(name) {
    Some(_) => true
    None => match self.parent {
      Some(parent) => parent.contains(name)
      None => false
    }
  }
}

fn Context::create(code: String, source_file~: String = "demo") -> Context {
  Context::{
    source_file,
    code,
    alltoks: Array::new(),
    tokinfos: Array::new(),
    typedefs: Env::new()
  }
}

//fn Context::is_typedef(self: Context, name: String) -> Bool {
//  self.typedefs.contains(name)
//}

fn Context::is_declspec_tok(self: Context, tok: Token) -> Bool {
  match tok {
    Void | Bool | Char | Short | Int | Long |
    Struct | Union | Typedef | Enum | Static | Extern |
    Alignas | Signed | Unsigned | Const | Volatile |
    Auto | Register | Restrict | Noreturn | Float | Double |
    Typeof | Inline | ThreadLocal | Atomic => true
    Identifier(name) => {
      // Check if the identifier is a typedef
      //self.typedefs.contains(name)
      //self.get_typedef(name) is Some(_)
      self.typedefs.contains(name)
    }
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
//  let ctx = Context::create(code, source_file="test.c")
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
//  println(ctx.get_warning_msg(6, "This is a test warning for variable 'x'"))
//
//  println("=== End Demo ===")
//}
