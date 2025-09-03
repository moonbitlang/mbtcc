///|
pub(all) struct Env[V] {
  vars : Map[String, V]
  mut parent : Env[V]?
}

///|
pub fn[V] Env::new() -> Env[V] {
  Env::{ vars: Map::new(), parent: None }
}

///|
pub fn[V] Env::get(self : Env[V], name : String) -> V? {
  match self.vars.get(name) {
    Some(v) => Some(v)
    None =>
      match self.parent {
        Some(parent) => parent.get(name)
        None => None
      }
  }
}

///|
pub fn[V] Env::set(self : Env[V], name : String, value : V) -> Unit {
  self.vars.set(name, value)
}

///|
pub fn[V] Env::contains(self : Env[V], name : String) -> Bool {
  match self.vars.get(name) {
    Some(_) => true
    None =>
      match self.parent {
        Some(parent) => parent.contains(name)
        None => false
      }
  }
}

