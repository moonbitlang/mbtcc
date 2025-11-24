///|
pub suberror PreprecessError {
  InvalidIncludePath(String)
  Unimplemented(String)
  InvalidMacroDefinition(String)
}

///|
using @lexer {type Token}

///|
///
/// In C, we have object-like and function-like macros.
///
/// object-like macro:
///
/// ```c
/// #define MAX_SIZE 100
/// #deifine PI 3.14
/// ```
///
/// function-like macro:
///
/// ```c
/// #define SQUARE(x) ((x) * (x))
/// #define MAX(a, b) ((a) > (b) ? (a) : (b))
/// ```
priv enum Macro {
  ObjLike(Array[Token])
  // param names, va_args, replacement tokens
  FuncLike(Array[String], String?, Array[Token])
}

///|
let macros : Map[String, Macro] = Map::new()

///|
pub fn preprocess(ctx : @lexer.Context) -> @lexer.Context raise PreprecessError {
  let { code, source_file, err_toks, .. } = ctx
  let path : @path.Path = source_file
  let dir = path.dirname()
  let new_tokens : Array[@lexer.Token] = Array::new()
  loop ctx.tokens[:] {
    [
      { kind: Hash, .. },
      { kind: Identifier("include"), .. },
      { kind: String(f), .. },
      .. rest,
    ] => {
      let fpath = dir.join(f).to_string()
      let include_code = @fs.read_file_to_string(fpath) catch {
        _ => raise InvalidIncludePath(fpath)
      }
      let include_ctx = @lexer.Context::new(
        code=include_code,
        source_file=fpath,
      )
      let _ = include_ctx.tokenize()
      let include_ctx = preprocess(include_ctx)
      let include_tokens = include_ctx.tokens
      let _ = include_tokens.pop() // remove EOF
      new_tokens.append(include_tokens)
      continue rest
    }
    // Func-like macro
    [
      { kind: Hash, .. },
      { kind: Identifier("define"), .. },
      { kind: Identifier(def_name), .. } as def_tok,
      { kind: Bracket('('), .. },
      .. rest,
    ] => {
      let params : Array[String] = Array::new()
      let rep_tokens : Array[Token] = Array::new()
      let mut va_arg_name : String? = None
      let rest = loop rest {
        [
          { kind: Identifier(name), .. },
          { kind: Ellipsis, .. },
          { kind: Bracket(')'), .. },
          .. rest,
        ] => {
          va_arg_name = Some(name)
          break rest
        }
        [{ kind: Ellipsis, .. }, { kind: Bracket(')'), .. }, .. rest] => {
          va_arg_name = Some("__VA_ARGS__")
          break rest
        }
        [{ kind: Bracket(')'), .. }, .. rest] => break rest
        [{ kind: Identifier(param), .. }, { kind: Comma, .. }, .. rest] => {
          params.push(param)
          continue rest
        }
        [{ kind: Identifier(param), .. }, .. rest] => {
          params.push(param)
          continue rest
        }
        [] as rest => break rest
        [_, ..] =>
          raise InvalidMacroDefinition(
            "Invalid function-like macro parameter list",
          )
      }
      let line = def_tok.line
      let rest = loop rest {
        [tok, ..] as rest if tok.line != line => break rest
        [tok, .. rest] => {
          rep_tokens.push(tok)
          continue rest
        }
        [] as rest => break rest
      }
      let macro_def = Macro::FuncLike(params, va_arg_name, rep_tokens)
      macros.set(def_name, macro_def)
      continue rest
    }
    // Obj-like macro
    [
      { kind: Hash, .. },
      { kind: Identifier("define"), .. },
      { kind: Identifier(defname), .. } as idtok,
      .. rest,
    ] => {
      let def_tokens : Array[Token] = Array::new()
      let line = idtok.line
      let rest = loop rest {
        [tok, ..] as rest if tok.line != line => break rest
        [tok, .. rest] => {
          def_tokens.push(tok)
          continue rest
        }
        [] as rest => break rest
      }
      let macro_def = Macro::ObjLike(def_tokens)
      macros.set(defname, macro_def)
      continue rest
    }
    [{ kind: Identifier(name), .. }, .. rest] if macros.get(name)
      is Some(ObjLike(toks)) => {
      new_tokens.append(toks)
      continue rest
    }
    [{ kind: Identifier(name), .. }, { kind: Bracket('('), .. }, .. rest] if macros.get(
        name,
      )
      is Some(FuncLike(params, va_args, rep_toks)) => {
      let mut paren_count = 0
      let mut brace_count = 0
      let mut bracket_count = 0
      let mut param_idx = 0
      let args : Map[String, Array[Token]] = Map::new()
      let mut current_arg_tokens : Array[Token] = Array::new()
      let va_args_tokens : Array[Token] = Array::new()
      let rest = loop rest {
        [{ kind: Bracket('('), .. } as tok, .. rest] => {
          paren_count += 1
          current_arg_tokens.push(tok)
          continue rest
        }
        [{ kind: Bracket(')'), .. } as tok, .. rest] if paren_count > 0 => {
          paren_count -= 1
          current_arg_tokens.push(tok)
          continue rest
        }
        [{ kind: Bracket(')'), .. }, .. rest] => {
          if param_idx < params.length() {
            args.set(params[param_idx], current_arg_tokens)
          } else if va_args is Some(_) {
            va_args_tokens.append(current_arg_tokens)
          }
          break rest
        }
        [{ kind: Bracket('{'), .. } as tok, .. rest] => {
          brace_count += 1
          current_arg_tokens.push(tok)
          continue rest
        }
        [{ kind: Bracket('}'), .. } as tok, .. rest] => {
          brace_count -= 1
          current_arg_tokens.push(tok)
          continue rest
        }
        [{ kind: Bracket('['), .. } as tok, .. rest] => {
          bracket_count += 1
          current_arg_tokens.push(tok)
          continue rest
        }
        [{ kind: Bracket(']'), .. } as tok, .. rest] => {
          bracket_count -= 1
          current_arg_tokens.push(tok)
          continue rest
        }
        [{ kind: Comma, .. } as comma_tok, .. rest] if (
            paren_count | brace_count | bracket_count
          ) ==
          0 => {
          if param_idx < params.length() {
            args.set(params[param_idx], current_arg_tokens)
            param_idx += 1
            current_arg_tokens = Array::new()
          } else {
            va_args_tokens.append(current_arg_tokens)
            va_args_tokens.push(comma_tok)
            current_arg_tokens = Array::new()
          }
          continue rest
        }
        [tok, .. rest] => {
          current_arg_tokens.push(tok)
          continue rest
        }
        [] as rest => break rest
      }
      // 如果有可变参数，将其加入到args中
      if va_args is Some(va_name) {
        args.set(va_name, va_args_tokens)
      }
      // 展开替换
      for rep_tok in rep_toks {
        if rep_tok.kind is Identifier(var_name) &&
          args.get(var_name) is Some(arg_tokens) {
          new_tokens.append(arg_tokens)
          continue
        }
        new_tokens.push(rep_tok)
      }
      continue rest
    }
    [tok, .. rest] => {
      new_tokens.push(tok)
      continue rest
    }
    [] => break
  }
  let new_ctx = @lexer.Context::{
    code,
    source_file,
    tokens: new_tokens,
    err_toks,
  }
  new_ctx
}

///|
test "Object Like define Test" {
  let code =
    #|#define MAX_SIZE 100
    #|MAX_SIZE + 20
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  inspect(tokens.length(), content="4")
  inspect(tokens[0].kind, content="100")
  inspect(tokens[1].kind, content="+")
  inspect(tokens[2].kind, content="20")
}

///|
test "Function Like define Test - 1" {
  let code =
    #|#define Plus1(a) ((a) + 1)
    #|Plus1(5)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  inspect(tokens.length(), content="8")
  inspect(tokens[0].kind, content="(")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="5")
  inspect(tokens[3].kind, content=")")
  inspect(tokens[4].kind, content="+")
  inspect(tokens[5].kind, content="1")
  inspect(tokens[6].kind, content=")")
}

///|
test "Function Like define Test - 2" {
  let code =
    #|#define Plus(a, b) ((a) + (b))
    #|Plus(5, 10)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  inspect(tokens.length(), content="10")
  inspect(tokens[0].kind, content="(")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="5")
  inspect(tokens[3].kind, content=")")
  inspect(tokens[4].kind, content="+")
  inspect(tokens[5].kind, content="(")
  inspect(tokens[6].kind, content="10")
  inspect(tokens[7].kind, content=")")
  inspect(tokens[8].kind, content=")")
}

///|
test "Function Like define Test - 3" {
  let code =
    #|#define Plus(a, b) ((a) + (b))
    #|Plus(foo(1, 2), { x, y })
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  inspect(tokens.length(), content="19")
  inspect(tokens[0].kind, content="(")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="foo")
  inspect(tokens[3].kind, content="(")
  inspect(tokens[4].kind, content="1")
  inspect(tokens[5].kind, content=",")
  inspect(tokens[6].kind, content="2")
  inspect(tokens[7].kind, content=")")
  inspect(tokens[8].kind, content=")")
  inspect(tokens[9].kind, content="+")
  inspect(tokens[10].kind, content="(")
  inspect(tokens[11].kind, content="{")
  inspect(tokens[12].kind, content="x")
  inspect(tokens[13].kind, content=",")
  inspect(tokens[14].kind, content="y")
  inspect(tokens[15].kind, content="}")
  inspect(tokens[16].kind, content=")")
  inspect(tokens[17].kind, content=")")
}

///|
test "VA_ARGS Test - 1: Basic __VA_ARGS__" {
  let code =
    #|#define LOG(...) printf(__VA_ARGS__)
    #|LOG("Hello", 42)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // printf("Hello", 42)
  inspect(tokens.length(), content="7")
  inspect(tokens[0].kind, content="printf")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="Hello")
  inspect(tokens[3].kind, content=",")
  inspect(tokens[4].kind, content="42")
  inspect(tokens[5].kind, content=")")
}

///|
test "VA_ARGS Test - 2: Named variadic args" {
  let code =
    #|#define LOG(args...) printf(args)
    #|LOG("Value: %d", x)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // printf("Value: %d", x)
  inspect(tokens.length(), content="7")
  inspect(tokens[0].kind, content="printf")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="Value: %d")
  inspect(tokens[3].kind, content=",")
  inspect(tokens[4].kind, content="x")
  inspect(tokens[5].kind, content=")")
}

///|
test "VA_ARGS Test - 3: Fixed + variadic args" {
  let code =
    #|#define LOG(fmt, ...) printf(fmt, __VA_ARGS__)
    #|LOG("Values: %d %d", 1, 2)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // printf("Values: %d %d", 1, 2)
  inspect(tokens.length(), content="9")
  inspect(tokens[0].kind, content="printf")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="Values: %d %d")
  inspect(tokens[3].kind, content=",")
  inspect(tokens[4].kind, content="1")
  inspect(tokens[5].kind, content=",")
  inspect(tokens[6].kind, content="2")
  inspect(tokens[7].kind, content=")")
}

///|
test "VA_ARGS Test - 4: Multiple fixed + variadic args" {
  let code =
    #|#define CALL(func, x, ...) func(x, __VA_ARGS__)
    #|CALL(foo, 10, 20, 30)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // foo(10, 20, 30)
  inspect(tokens.length(), content="9")
  inspect(tokens[0].kind, content="foo")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="10")
  inspect(tokens[3].kind, content=",")
  inspect(tokens[4].kind, content="20")
  inspect(tokens[5].kind, content=",")
  inspect(tokens[6].kind, content="30")
  inspect(tokens[7].kind, content=")")
}
