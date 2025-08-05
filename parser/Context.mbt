
struct Context {
  code: String
  alltoks: Array[Token]
  mut typedefs: Env[Int]
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

fn Context::create(code: String) -> Context {
  Context::{
    code: code,
    alltoks: Array::new(),
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
