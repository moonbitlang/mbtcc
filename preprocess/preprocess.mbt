///|
pub suberror PreprecessError {
  InvalidIncludePath(String)
}

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
