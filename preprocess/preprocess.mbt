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
priv enum CondInclStateKind {
  Then
  Elif
  Else
}

///|
priv struct CondInclState {
  mut kind : CondInclStateKind
  mut included : Bool
}

///|
let cond_incl_stack : Array[CondInclState] = Array::new()

///|
pub fn preprocess(ctx : @lexer.Context) -> @lexer.Context raise PreprecessError {
  let { code, source_file, err_toks, .. } = ctx
  let path : @path.Path = source_file
  let dir = path.dirname()
  let new_tokens : Array[@lexer.Token] = Array::new()
  loop ctx.tokens[:] {
    // handle include directive
    // e.g: `#include "file.h"`
    [
      { kind: Hash, .. },
      { kind: Identifier("include"), .. },
      { kind: String(f), .. },
      .. rest,
    ] => {
      let fpath = dir.join(f).to_string()
      let include_code = try @fs.read_file_to_string(fpath) catch {
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
    // handle undef directive
    // e.g: `#undef MACRO_NAME`
    [
      { kind: Hash, .. },
      { kind: Identifier("undef"), .. },
      { kind: Identifier(name), .. },
      .. rest,
    ] => {
      macros.remove(name)
      continue rest
    }
    // invalid undef usage
    [{ kind: Hash, .. }, { kind: Identifier("undef"), .. }, tok, ..] =>
      raise InvalidMacroDefinition("Invalid macro name in undef: \{tok}")
    // define Func-like macro
    // e.g: `#define MAX(a, b) ((a) > (b) ? (a) : (b))`
    [
      { kind: Hash, .. },
      { kind: Identifier("define"), .. },
      { kind: Identifier(def_name), line, .. },
      { kind: Bracket('('), .. },
      .. rest,
    ] => {
      let params : Array[String] = Array::new()
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
      let (rep_tokens, rest) = collect_tokens_until_new_line(line, rest)
      let macro_def = Macro::FuncLike(params, va_arg_name, rep_tokens)
      macros.set(def_name, macro_def)
      continue rest
    }
    // define Obj-like macro
    // e.g: `#define PI 3.14`
    [
      { kind: Hash, .. },
      { kind: Identifier("define"), .. },
      { kind: Identifier(defname), line, .. },
      .. rest,
    ] => {
      let (def_tokens, rest) = collect_tokens_until_new_line(line, rest)
      let macro_def = Macro::ObjLike(def_tokens)
      macros.set(defname, macro_def)
      continue rest
    }
    // Handle conditional inclusion - if
    // e.g. `#if expr`
    [{ kind: Hash, .. }, { kind: Keyword(If), line, .. }, .. rest] => {
      let (val, rest) = eval_const_expr(line, rest)
      let included = val != 0
      let cond_incl = CondInclState::{ kind: Then, included }
      cond_incl_stack.push(cond_incl)
      let rest = if included { rest } else { skip_cond_incl(rest) }
      continue rest
    }
    // Handle conditional inclusion - ifdef
    [
      { kind: Hash, .. },
      { kind: Identifier("ifdef"), .. },
      { kind: Identifier(name), .. },
      .. rest,
    ] => {
      let included = macros.get(name) is Some(_)
      let cond_incl = CondInclState::{ kind: Then, included }
      cond_incl_stack.push(cond_incl)
      let rest = if included { rest } else { skip_cond_incl(rest) }
      continue rest
    }
    // Handle conditional inclusion - ifndef
    [
      { kind: Hash, .. },
      { kind: Identifier("ifndef"), .. },
      { kind: Identifier(name), .. },
      .. rest,
    ] => {
      let included = macros.get(name) is None
      let cond_incl = CondInclState::{ kind: Then, included }
      cond_incl_stack.push(cond_incl)
      let rest = if included { rest } else { skip_cond_incl(rest) }
      continue rest
    }
    [{ kind: Hash, .. } as hash_tok, { kind: Identifier("elif"), .. }, ..] if cond_incl_stack.is_empty() =>
      raise StrayElse(hash_tok, "elif without matching if")
    [
      { kind: Hash, .. } as hash_tok,
      { kind: Identifier("elif"), line, .. },
      .. rest,
    ] => {
      let prev_state = cond_incl_stack.last().unwrap()
      guard !(prev_state.kind is Else) else {
        raise StrayElse(hash_tok, "elif after else")
      }
      prev_state.kind = Elif
      if prev_state.included {
        let rest = skip_cond_incl(rest)
        continue rest
      }
      let (val, rest) = eval_const_expr(line, rest)
      let included = val != 0
      prev_state.included = included
      let rest = if included { rest } else { skip_cond_incl(rest) }
      continue rest
    }
    // Handle conditional inclusion - else
    [{ kind: Hash, .. } as hash_tok, { kind: Identifier("else"), .. }, ..] if cond_incl_stack.is_empty() =>
      raise StrayElse(hash_tok, "else without matching if")
    [{ kind: Hash, .. } as hash_tok, { kind: Identifier("else"), .. }, .. rest] => {
      let prev_state = cond_incl_stack.last().unwrap()
      guard !(prev_state.kind is Else) else {
        raise StrayElse(hash_tok, "multiple else in the same if block")
      }
      prev_state.kind = Else
      let rest = if prev_state.included {
        skip_cond_incl(rest)
      } else {
        prev_state.included = true
        rest
      }
      continue rest
    }
    // Handle conditional inclusion - endif
    // e.g. `#endif`
    [{ kind: Hash, .. } as hash_tok, { kind: Identifier("endif"), .. }, ..] if cond_incl_stack.is_empty() =>
      raise StrayElse(hash_tok, "endif without matching if")
    [{ kind: Hash, .. }, { kind: Identifier("endif"), .. }, .. rest] => {
      let _ = cond_incl_stack.pop()
      continue rest
    }
    // Expand object-like macro
    [{ kind: Identifier(name), .. }, .. rest] if macros.get(name) is Some(_) => {
      let (new_toks, rest) = replace_identifier(name, rest)
      new_tokens.append(new_toks)
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
fn eval_const_expr(
  line : Int,
  tokens : ArrayView[Token],
) -> (Int64, ArrayView[Token]) raise PreprecessError {
  if tokens is [{ kind: Identifier("defined"), .. }, .. tokens] {
    let (has_paren, tokens) = if tokens
      is [{ kind: Bracket('('), .. }, .. tokens] {
      (true, tokens)
    } else {
      (false, tokens)
    }
    guard tokens is [{ kind: Identifier(name), .. }, .. tokens] else {
      raise InvalidConstExprToken(tokens[0], "macro name must be an identifier")
    }
    let tokens = if has_paren {
      guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
        raise InvalidConstExprToken(tokens[0], "expected closing parenthesis")
      }
      tokens
    } else {
      tokens
    }
    let val = (macros.get(name) is Some(_)).to_int64()
    return (val, tokens)
  }
  let (const_expr_tokens, rest) = collect_tokens_until_new_line(line, tokens)
  const_expr_tokens.push(@lexer.dummy_eof())
  let (const_expr, _) = parse_constant_expr(const_expr_tokens)
  let val = const_expr.eval()
  (val, rest)
}

///|
fn collect_tokens_until_new_line(
  line : Int,
  tokens : ArrayView[Token],
) -> (Array[Token], ArrayView[Token]) {
  let new_tokens : Array[Token] = Array::new()
  let rest = loop tokens {
    [tok, .. rest] if tok.line == line => {
      new_tokens.push(tok)
      continue rest
    }
    tokens => break tokens
  }
  (new_tokens, rest)
}

///|
fn skip_cond_incl(tokens : ArrayView[Token]) -> ArrayView[Token] {
  loop tokens {
    [
      { kind: Hash, .. },
      { kind: Identifier("if" | "ifdef" | "ifndef"), .. },
      .. rest,
    ] => break skip_cond_incl2(rest)
    [
      { kind: Hash, .. },
      { kind: Identifier("elif" | "else" | "endif"), .. },
      .. rest,
    ] => break rest
    [_, .. rest] => continue rest
    [] as tokens => break tokens
  }
}

///|
fn skip_cond_incl2(tokens : ArrayView[Token]) -> ArrayView[Token] {
  loop tokens {
    [
      { kind: Hash, .. },
      { kind: Identifier("if" | "ifdef" | "ifndef"), .. },
      .. rest,
    ] => break skip_cond_incl2(rest)
    [{ kind: Hash, .. }, { kind: Identifier("endif"), .. }, .. rest] =>
      break rest
    [_, .. rest] => continue rest
    [] as tokens => break tokens
  }
}

///|
fn replace_identifier(
  id : String,
  rest_tokens : ArrayView[Token],
) -> (Array[Token], ArrayView[Token]) raise PreprecessError {
  let cmacro = macros.get(id).unwrap()
  if cmacro is ObjLike(toks) {
    return (toks, rest_tokens)
  }
  guard cmacro is FuncLike(params, va_args, rep_toks)
  guard rest_tokens is [{ kind: Bracket('('), .. }, .. rest] else {
    raise InvalidMacorInvocation(
      "Macro \{id} requires arguments but none provided",
    )
  }
  let new_tokens : Array[Token] = Array::new()
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
  if va_args is Some(va_name) {
    args.set(va_name, va_args_tokens)
  }
  for rep_tok in rep_toks {
    if rep_tok.kind is Identifier(var_name) &&
      args.get(var_name) is Some(arg_tokens) {
      new_tokens.append(arg_tokens)
      continue
    }
    new_tokens.push(rep_tok)
  }
  (new_tokens, rest)
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
