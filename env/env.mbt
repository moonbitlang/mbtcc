///|
pub(all) struct Env[K, V] {
  map : Map[K, V]
  parent : Env[K, V]?
}

///|
pub fn[K, V] Env::new(parent? : Env[K, V]? = None) -> Env[K, V] {
  Env::{ map: Map::new(), parent }
}

///|
pub fn[K : Hash + Eq, V] Env::get(self : Self[K, V], key : K) -> V? {
  match self.map.get(key) {
    Some(value) => Some(value)
    None =>
      match self.parent {
        Some(parent) => parent.get(key)
        None => None
      }
  }
}

///|
pub fn[K : Hash + Eq, V] Env::set(
  self : Self[K, V],
  key : K,
  value : V,
) -> Unit {
  self.map.set(key, value)
}

///|
pub fn[K : Hash + Eq, V] Env::contains_global(
  self : Self[K, V],
  key : K,
) -> Bool {
  match self.map.contains(key) {
    true => true
    false =>
      match self.parent {
        Some(parent) => parent.contains_global(key)
        None => false
      }
  }
}

///|
pub fn[K : Hash + Eq, V] Env::contains_local(
  self : Self[K, V],
  key : K,
) -> Bool {
  self.map.contains(key)
}
