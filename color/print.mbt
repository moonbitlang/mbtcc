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
}

///|
pub fn taint(msg : String, color : Color) -> String {
  match color {
    Red => "\x1b[31m\{msg}\x1b[0m"
    Yellow => "\x1b[33m\{msg}\x1b[0m"
    Magenta => "\x1b[35m\{msg}\x1b[0m"
  }
}
