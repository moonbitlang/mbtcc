enum Type {
  Void
  Int8
  UInt8
  Int16
  UInt16
  Int32
  Int64
  UInt32
  UInt64
  Bool
  Float
  Double
  LongDouble
  Ptr(Type)
  Struct(Array[Type], is_flexible~:Bool, is_packed~:Bool) // 
  Union(Array[Type])
  Function(Array[Type], Type, is_variadic~: Bool)
  // VLA
}

struct Context {
  code: String
  alltoks: Array[Token]
  mut rest_toks: @array.View[Token]
  typedefs: Env[Type]
}

struct Env[V] {
  vars: Map[String, V]
  parent: Env[V]?
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

fn[V] Env::contains(self: Env[V], name: String) -> Bool {
  match self.vars.get(name) {
    Some(_) => true
    None => match self.parent {
      Some(parent) => parent.contains(name)
      None => false
    }
  }
}

fn Context::create(code: String) -> Context {
  Context::{
    code: code,
    alltoks: Array::new(),
    rest_toks: [],
    typedefs: Env::new()
  }
}

fn Context::is_declspec_tok(self: Context, tok: Token) -> Bool {
  match tok {
    Void | Bool | Char | Short | Int | Long |
    Struct | Union | Typedef | Enum | Static | Extern |
    Alignas | Signed | Unsigned | Const | Volatile |
    Auto | Register | Restrict | Noreturn | Float | Double |
    Typeof | Inline | ThreadLocal | Atomic => true
    Identifier(name) => {
      // Check if the identifier is a typedef
      self.typedefs.contains(name)
    }
    _ => false
  }
}
