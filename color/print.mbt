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
pub(all) enum Color {
  Red
  Yellow
  Magenta
  Green
  Blue
}

///|
pub fn taint(msg : String, color : Color) -> String {
  match color {
    Red => "\u{1b}[31m\{msg}\u{1b}[0m"
    Yellow => "\u{1b}[33m\{msg}\u{1b}[0m"
    Magenta => "\u{1b}[35m\{msg}\u{1b}[0m"
    Green => "\u{1b}[32m\{msg}\u{1b}[0m"
    Blue => "\u{1b}[34m\{msg}\u{1b}[0m"
  }
}

pub fn strip_color(msg : String) -> String {
  msg
  .replace(old="\u{1b}[31m", new="")
  .replace(old="\u{1b}[32m", new="")
  .replace(old="\u{1b}[33m", new="")
  .replace(old="\u{1b}[34m", new="")
  .replace(old="\u{1b}[35m", new="")
  .replace(old="\u{1b}[0m", new="")
}

pub fn[T: Show] strip_object_color(obj : T) -> String {
  let msg = obj.to_string()
  strip_color(msg)
}
