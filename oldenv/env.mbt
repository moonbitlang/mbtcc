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
