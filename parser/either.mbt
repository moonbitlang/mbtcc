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
pub(all) enum Either[L, R] {
  Left(L)
  Right(R)
} derive(Show, Eq)

///|
pub fn[L, R] Either::is_left(self : Either[L, R]) -> Bool {
  match self {
    Left(_) => true
    _ => false
  }
}

///|
pub fn[L, R] Either::is_right(self : Either[L, R]) -> Bool {
  match self {
    Right(_) => true
    _ => false
  }
}

///|
pub fn[L, R] Either::left(self : Either[L, R]) -> L? {
  match self {
    Left(t) => Some(t)
    _ => None
  }
}

///|
pub fn[L, R] Either::right(self : Either[L, R]) -> R? {
  match self {
    Right(k) => Some(k)
    _ => None
  }
}

///|
pub fn[L, R] Either::left_unwrap(self : Either[L, R]) -> L {
  match self {
    Left(t) => t
    _ => abort("Either::left_unwrap: not a left")
  }
}

///|
pub fn[L, R] Either::right_unwrap(self : Either[L, R]) -> R {
  match self {
    Right(k) => k
    _ => abort("Either::right_unwrap: not a right")
  }
}

///|
pub fn[L, R] Either::expect_left(self : Either[L, R], msg : String) -> L {
  match self {
    Left(t) => t
    _ => abort(msg)
  }
}

///|
pub fn[L, R] Either::expect_right(self : Either[L, R], msg : String) -> R {
  match self {
    Right(k) => k
    _ => abort(msg)
  }
}
