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
suberror ArgError {
  NoInputFiles(String)
  InValidOption(String)
}

///|
fn main_err() -> Unit raise {
  let usage =
    #|Usage: mbtcc [options] <input files>
    #|
    #|Options:
    #|  --print-tokens, -toks      Stop after lexing phase and print tokens.
    #|  --print-ast, -ast          Stop after parsing phase and print AST.
    #|  --Expand, -E               Run the preprocessor only.
  let other_options : Array[String] = Array::new()
  let output : Ref[String] = @ref.new("")
  let print_tokens : Ref[Bool] = @ref.new(false)
  let print_ast : Ref[Bool] = @ref.new(false)
  let expand_only : Ref[Bool] = @ref.new(false)
  let spec : Array[(String, String, @ArgParser.Spec, String)] = [
    (
      "--Expand",
      "-E",
      Set(expand_only),
      "Run the preprocessor only.",
    ),
    (
      "--print-tokens",
      "-toks",
      Set(print_tokens),
      "Stop after lexing phase and print tokens.",
    ),
    (
      "--print-ast",
      "-ast",
      Set(print_ast),
      "Stop after parsing phase and print AST.",
    ),
    ("--output", "-o", Set_string(output), "Specify output file name."),
  ]
  let args = @env.args()[1:].to_array()
  @ArgParser.parse(spec, opt => other_options.push(opt), usage, args)
  let files : Array[String] = Array::new()
  let print_tokens = print_tokens.val
  // let print_ast = print_ast.val
  for opt in other_options {
    if opt.has_suffix(".c") {
      files.push(opt)
    } else {
      raise InValidOption("Invalid option `\{opt}`.")
    }
  }
  if files.length() == 0 {
    raise NoInputFiles("No input files specified.")
  }
  for source_file in files {
    let code = @fs.read_file_to_string(source_file)
    let lexer_ctx = @lexer.Context::new(code~, source_file~)
    let _ = lexer_ctx.tokenize()
    let lexer_ctx = @preprocess.preprocess(lexer_ctx)
    if expand_only.val {
      let expanded_code = @lexer.restore_code_from_tokens(lexer_ctx.tokens)
      println(expanded_code)
      continue
    }
    let ctx = @parser.Context::from_lexer(lexer_ctx)
    if print_tokens {
      println(ctx.tokens)
    } else {
      let prog = ctx.parse()
      println(prog)
    }
  }
}

///|
fn main {
  main_err() catch {
    @ArgParser.ErrorMsg(msg) => println(msg)
    NoInputFiles(msg) => {
      println(msg)
      panic()
    }
    InValidOption(msg) => {
      println(msg)
      panic()
    }
    err => {
      println("Compilation error: \{err}")
      panic()
    }
  }
}
