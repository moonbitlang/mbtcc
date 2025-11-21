///|
pub suberror PreprecessError {
  InvalidIncludePath(String)
  Unimplemented(String)
}

using @lexer { type Token }

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
  // FuncLike(Array[String], Array[Token])
}

let macros: Map[String, Macro] = Map::new()

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
    // Func-like macro
    [{kind: Hash, ..},
     { kind: Identifier("define"), .. },
     { kind: Identifier(_), .. },
     { kind: Bracket('('), .. }, ..] => {
      raise Unimplemented("Function-like macros are not yet implemented.")
    }
    // Obj-like macro
    [{kind: Hash, ..}, { kind: Identifier("define"), .. }, { kind: Identifier(defname), .. } as idtok, .. rest] => {
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
    [{ kind: Identifier(name), .. }, .. rest] if
    macros.get(name) is Some(ObjLike(toks)) => {
      new_tokens.append(toks)
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
