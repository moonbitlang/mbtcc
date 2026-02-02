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
// Stringizing operator: `#param` in function-like macro replacement list.
// We approximate C's stringizing by concatenating original token spellings
// (Token.raw) and escaping `\` and `"` (similar to chibicc's approach).
fn stringize_macro_arg(code : StringView, arg_tokens : Array[Token]) -> String {
  if arg_tokens.is_empty() {
    return ""
  }
  let sb = StringBuilder::new()
  // C stringizing: replace each run of whitespace between tokens with a single space.
  // We approximate this by looking at the original source slice between token spans
  // via `tok.idx` + `tok.raw.length()`.
  //
  // If `code` is unavailable (empty) or the indices are out of range, we fall back
  // to concatenating token spellings without spaces.
  for i in 0..<arg_tokens.length() {
    let tok = arg_tokens[i]
    sb.write_string(tok.raw)
    if i + 1 < arg_tokens.length() && code.length() > 0 {
      let next = arg_tokens[i + 1]
      let gap_start = tok.idx + tok.raw.length()
      let gap_end = next.idx
      if gap_end > gap_start && gap_end <= code.length() && gap_start >= 0 {
        let gap = code.view(start_offset=gap_start, end_offset=gap_end)
        // If there was any whitespace between tokens, output a single space.
        let mut has_ws = false
        for ch in gap {
          if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
            has_ws = true
            break
          }
        }
        if has_ws {
          sb.write_string(" ")
        }
      }
    }
  }
  sb.to_string()
}

///|
fn has_ws_between(code : StringView, a : Token, b : Token) -> Bool {
  if code.length() == 0 {
    return false
  }
  if a.line != b.line {
    return true
  }
  let start = a.idx + a.raw.length()
  let end = b.idx
  if end > start && start >= 0 && end <= code.length() {
    let gap = code.view(start_offset=start, end_offset=end)
    for ch in gap {
      if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
        return true
      }
    }
  }
  // Fallback to column-based check in case idx math is off.
  if b.col > a.col + a.raw.length() {
    return true
  }
  false
}

///|
fn strip_attribute_tokens(tokens : Array[Token]) -> Array[Token] {
  let out : Array[Token] = Array::new()
  loop tokens[:] {
    [
      { kind: Keyword(Attribute), .. },
      { kind: Bracket('('), .. },
      { kind: Bracket('('), .. },
      .. rest,
    ] => {
      let mut depth = 2
      let mut ctor_tok : Token? = None
      let mut dtor_tok : Token? = None
      let rest = loop rest {
        [{ kind: Bracket('('), .. }, .. rest2] => {
          depth = depth + 1
          continue rest2
        }
        [{ kind: Bracket(')'), .. }, .. rest2] => {
          depth = depth - 1
          if depth == 0 {
            break rest2
          }
          continue rest2
        }
        [{ kind: Identifier(name), .. } as id_tok, .. rest2] => {
          if name == "constructor" || name == "__constructor__" {
            ctor_tok = Some(id_tok)
          } else if name == "destructor" || name == "__destructor__" {
            dtor_tok = Some(id_tok)
          }
          continue rest2
        }
        [_, .. rest2] => continue rest2
        [] as rest2 => break rest2
      }
      match ctor_tok {
        Some(tok) => out.push(tok)
        None => ()
      }
      match dtor_tok {
        Some(tok) => out.push(tok)
        None => ()
      }
      continue rest
    }
    [tok, .. rest] => {
      out.push(tok)
      continue rest
    }
    [] => break
  }
  out
}

///|
let macros : Map[String, Macro] = Map::new()
let macro_stack : Map[String, Array[Macro?]] = Map::new()

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
///
/// `Path -> Tokens`
let pragma_once : Set[String] = Set::new()

///|
let line_offset : Ref[Int] = @ref.new(0)

///|
fn find_substring(hay : String, needle : String) -> Int? {
  if needle.length() == 0 {
    return Some(0)
  }
  if hay.length() < needle.length() {
    return None
  }
  let limit = hay.length() - needle.length()
  for i = 0; i <= limit; i = i + 1 {
    if hay.substring(start=i, end=i + needle.length()) == needle {
      return Some(i)
    }
  }
  None
}

///|
fn path_dirname(path : String) -> String {
  if path.length() == 0 {
    return "."
  }
  let mut i = path.length() - 1
  while i >= 0 {
    let ch = path.substring(start=i, end=i + 1)
    if ch == "/" {
      if i == 0 {
        return "/"
      }
      return path.substring(start=0, end=i)
    }
    i = i - 1
  }
  "."
}

///|
fn path_join(dir : String, name : String) -> String {
  if dir == "" || dir == "." {
    return name
  }
  if dir.substring(start=dir.length() - 1, end=dir.length()) == "/" {
    return dir + name
  }
  dir + "/" + name
}

///|
fn init_builtin_macros(template : Token) -> Unit {
  // __LP64__ on typical 64-bit Unix/macOS
  let one = @lexer.dummy_long(1, raw="1")
  macros.set("__LP64__", Macro::ObjLike([one]))
  macros.set("__APPLE__", Macro::ObjLike([one]))
  macros.set("__MACH__", Macro::ObjLike([one]))
  // __builtin_expect(x, y) -> x (handled specially in macro expansion)
  let rep : Array[Token] = Array::new()
  macros.set("__builtin_expect", Macro::FuncLike(["x", "y"], None, rep))
}

///|
fn reset_preprocess_state(template : Token) -> Unit {
  macros.clear()
  macro_stack.clear()
  cond_incl_stack.clear()
  pragma_once.clear()
  line_offset.val = 0
  init_builtin_macros(template)
}

///|
pub fn preprocess_root(ctx : @lexer.Context) -> @lexer.Context raise PreprecessError {
  reset_preprocess_state(@lexer.dummy_eof())
  preprocess(ctx)
}

///|
pub fn preprocess(ctx : @lexer.Context) -> @lexer.Context raise PreprecessError {
  let { code, source_file, err_toks, .. } = ctx
  let dir = path_dirname(source_file)
  let new_tokens : Array[@lexer.Token] = Array::new()
  loop ctx.tokens[:] {
    // handle #line directive
    [
      { kind: Hash, line, .. },
      { kind: Identifier("line"), .. },
      .. rest,
    ] => {
      let (val, rest) = eval_const_expr_no_undef(code[:], line, rest)
      // The next line after the directive is numbered as `val`.
      line_offset.val = val.to_int() - (line + 1)
      continue rest
    }
    // Skip __attribute__((...)) (ignored attributes)
    [
      { kind: Keyword(Attribute), .. },
      { kind: Bracket('('), .. },
      { kind: Bracket('('), .. },
      .. rest,
    ] => {
      let mut depth = 2
      let mut ctor_tok : Token? = None
      let mut dtor_tok : Token? = None
      let rest = loop rest {
        [{ kind: Bracket('('), .. }, .. rest2] => {
          depth = depth + 1
          continue rest2
        }
        [{ kind: Bracket(')'), .. }, .. rest2] => {
          depth = depth - 1
          if depth == 0 {
            break rest2
          }
          continue rest2
        }
        [{ kind: Identifier(name), .. } as id_tok, .. rest2] => {
          if name == "constructor" || name == "__constructor__" {
            ctor_tok = Some(id_tok)
          } else if name == "destructor" || name == "__destructor__" {
            dtor_tok = Some(id_tok)
          }
          continue rest2
        }
        [_, .. rest2] => continue rest2
        [] as rest2 => break rest2
      }
      match ctor_tok {
        Some(tok) => new_tokens.push(tok)
        None => ()
      }
      match dtor_tok {
        Some(tok) => new_tokens.push(tok)
        None => ()
      }
      continue rest
    }
    // handle include directive
    // e.g: `#include "file.h"`
    [
      { kind: Hash, .. },
      { kind: Identifier("include"), .. },
      { kind: String(f), line, .. },
      .. rest,
    ] => {
      let fpath = path_join(dir, f)
      if pragma_once.contains(fpath) {
        continue skip_line(line, rest)
      }
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
      continue skip_line(line, rest)
    }
    [
      { kind: Hash, .. },
      { kind: Identifier("include"), .. },
      { kind: Operator("<"), .. },
      .. rest,
    ] => {
      // collect tokens until '>'
      let name_tokens : Array[Token] = Array::new()
      let rest = loop rest {
        [{ kind: Operator(">"), line, .. }, .. rest2] => break rest2
        [tok, .. rest2] => {
          name_tokens.push(tok)
          continue rest2
        }
        [] as rest2 => break rest2
      }
      let mut fname = ""
      for t in name_tokens {
        fname = fname + t.raw
      }
      // search include dirs
      let include_dirs : Array[String] = Array::new()
      include_dirs.push(dir)
      include_dirs.push(path_join(dir, "headers"))
      match @env.current_dir() {
        Some(cwd) => {
          include_dirs.push(cwd)
          include_dirs.push(path_join(cwd, "headers"))
        }
        None => ()
      }
      match find_substring(source_file, "/mbtcc/") {
        Some(idx) => {
          let root = source_file.substring(start=0, end=idx + 6)
          include_dirs.push(path_join(root, "headers"))
        }
        None => ()
      }
      let mut include_code : String? = None
      let mut used_path = ""
      for d in include_dirs {
        let cand = path_join(d, fname)
        if @fs.path_exists(cand) {
          let code2 = @fs.read_file_to_string(cand) catch { _ => "" }
          include_code = Some(code2)
          used_path = cand
          break
        }
      }
      guard include_code is Some(code2) else {
        raise InvalidIncludePath(fname)
      }
      if pragma_once.contains(used_path) {
        continue rest
      }
      let include_ctx = @lexer.Context::new(
        code=include_code.unwrap(),
        source_file=used_path,
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
      { kind: Identifier(def_name), line, .. } as name_tok,
      { kind: Bracket('('), .. } as paren_tok,
      .. rest,
    ] if !has_ws_between(code[:], name_tok, paren_tok) => {
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
        [tok, ..] => {
          println(
            "Invalid macro params: \{def_name} at \{tok.source_file}:\{tok.line}",
          )
          raise InvalidMacroDefinition(
            "Invalid function-like macro parameter list: \{def_name} at \{tok.source_file}:\{tok.line}",
          )
        }
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
      let (val, rest) = eval_const_expr(code[:], line, rest)
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
      guard prev_state.kind is (Then | Elif) else {
        raise StrayElse(hash_tok, "elif after else")
      }
      prev_state.kind = Elif
      if prev_state.included {
        let rest = skip_cond_incl(rest)
        continue rest
      }
      let (val, rest) = eval_const_expr(code[:], line, rest)
      let included = val != 0
      prev_state.included = included
      let rest = if included { rest } else { skip_cond_incl(rest) }
      continue rest
    }
    // Handle conditional inclusion - else
    [{ kind: Hash, .. } as hash_tok, { kind: Keyword(Else), .. }, ..] if cond_incl_stack.is_empty() =>
      raise StrayElse(hash_tok, "else without matching if")
    [{ kind: Hash, .. } as hash_tok, { kind: Keyword(Else), .. }, .. rest] => {
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
    [
      { kind: Hash, .. },
      { kind: Identifier("pragma"), .. },
      { kind: Identifier("once"), line, .. },
      .. rest,
    ] => {
      pragma_once.add(source_file)
      continue skip_line(line, rest)
    }
    [
      { kind: Hash, .. },
      { kind: Identifier("pragma"), .. },
      { kind: Identifier("push_macro"), .. },
      { kind: Bracket('('), .. },
      { kind: String(name), line, .. },
      { kind: Bracket(')'), .. },
      .. rest,
    ] => {
      let stack = match macro_stack.get(name) {
        Some(s) => s
        None => {
          let s : Array[Macro?] = Array::new()
          macro_stack.set(name, s)
          s
        }
      }
      stack.push(macros.get(name))
      continue skip_line(line, rest)
    }
    [
      { kind: Hash, .. },
      { kind: Identifier("pragma"), .. },
      { kind: Identifier("pop_macro"), .. },
      { kind: Bracket('('), .. },
      { kind: String(name), line, .. },
      { kind: Bracket(')'), .. },
      .. rest,
    ] => {
      match macro_stack.get(name) {
        Some(stack) => {
          if stack.length() > 0 {
            let prev = stack.pop().unwrap()
            match prev {
              Some(m) => macros.set(name, m)
              None => macros.remove(name)
            }
          }
        }
        None => ()
      }
      continue skip_line(line, rest)
    }
    // Skip other #pragma directives (ignored)
    [
      { kind: Hash, line, .. },
      { kind: Identifier("pragma"), .. },
      .. rest,
    ] => {
      continue skip_line(line, rest)
    }
    // Expand object-like macro
    [{ kind: Identifier(name), .. } as tok, .. rest] if macros.get(name)
      is Some(_) => {
      let (new_toks, rest) = replace_identifier(code[:], tok, name, rest)
      new_tokens.append(new_toks)
      continue rest
    }
    // Builtin macros
    [{ kind: Identifier("__LINE__"), .. } as tok, .. rest] => {
      let line_val = tok.line + line_offset.val
      let t = @lexer.dummy_long(line_val.to_int64(), raw="\{line_val}")
      new_tokens.push(t)
      continue rest
    }
    [{ kind: Identifier("__FILE__"), .. } as tok, .. rest] => {
      let t = @lexer.string_token_like(tok, source_file)
      new_tokens.push(t)
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
  code : StringView,
  line : Int,
  tokens : ArrayView[Token],
) -> (Int64, ArrayView[Token]) raise PreprecessError {
  let (const_expr_tokens, rest) = collect_num_tokens_until_new_line(
    line, tokens,
  )
  let const_expr_tokens = expand_macro_for_tokens(code, const_expr_tokens)
  const_expr_tokens.push(@lexer.dummy_eof())
  let (const_expr, _) = parse_constant_expr(const_expr_tokens)
  let val = const_expr.eval().to_int64()
  (val, rest)
}

///|
fn eval_const_expr_no_undef(
  code : StringView,
  line : Int,
  tokens : ArrayView[Token],
) -> (Int64, ArrayView[Token]) raise PreprecessError {
  let (const_expr_tokens, rest) = collect_tokens_until_new_line(line, tokens)
  let const_expr_tokens = expand_macro_for_tokens(code, const_expr_tokens)
  const_expr_tokens.push(@lexer.dummy_eof())
  let (const_expr, _) = parse_constant_expr(const_expr_tokens)
  let val = const_expr.eval().to_int64()
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
fn expand_macro_for_tokens(
  code : StringView,
  tokens : Array[Token],
) -> Array[Token] raise PreprecessError {
  let new_tokens : Array[Token] = Array::new()
  loop tokens[:] {
    [{ kind: Identifier(name), .. } as tok, .. rest] if macros.get(name)
      is Some(_) => {
      let (expanded_toks, rest) = replace_identifier(code, tok, name, rest)
      new_tokens.append(expanded_toks)
      continue rest
    }
    [{ kind: Identifier("__LINE__"), .. } as tok, .. rest] => {
      let v = (tok.line + line_offset.val).to_int64()
      new_tokens.push(@lexer.dummy_long(v, raw="\{v}"))
      continue rest
    }
    [{ kind: Identifier("__FILE__"), .. } as tok, .. rest] => {
      new_tokens.push(@lexer.string_token_like(tok, tok.source_file))
      continue rest
    }
    [tok, .. rest] => {
      new_tokens.push(tok)
      continue rest
    }
    [] => break
  }
  new_tokens
}

// If met `defined(M)` or `defined M`, handle it here, replace it with 1 or 0

///|
fn collect_num_tokens_until_new_line(
  line : Int,
  tokens : ArrayView[Token],
) -> (Array[Token], ArrayView[Token]) {
  let new_tokens : Array[Token] = Array::new()
  let rest = loop tokens {
    [tok, .. rest] as tokens if tok.line != line => break tokens
    [
      { kind: Identifier("defined"), .. },
      { kind: Bracket('('), .. },
      { kind: Identifier(macro_name), .. },
      { kind: Bracket(')'), .. },
      .. rest,
    ] => {
      let val = (macros.get(macro_name) is Some(_)).to_int64()
      let tok = @lexer.dummy_long(val, raw="defined(\{macro_name})")
      new_tokens.push(tok)
      continue rest
    }
    [
      { kind: Identifier("defined"), .. },
      { kind: Identifier(macro_name), .. },
      .. rest,
    ] => {
      let val = (macros.get(macro_name) is Some(_)).to_int64()
      let tok = @lexer.dummy_long(val, raw="defined \{macro_name}")
      new_tokens.push(tok)
      continue rest
    }
    [{ kind: Identifier("__LINE__"), .. } as tok, .. rest] => {
      let v = (tok.line + line_offset.val).to_int64()
      new_tokens.push(@lexer.dummy_long(v, raw="\{v}"))
      continue rest
    }
    [{ kind: Identifier("__FILE__"), .. } as tok, .. rest] => {
      new_tokens.push(@lexer.string_token_like(tok, tok.source_file))
      continue rest
    }
    [{ kind: Identifier(name), .. } as tok, .. rest] => {
      // Undefined identifiers in #if are replaced with 0; defined ones are left
      // for macro expansion.
      match macros.get(name) {
        Some(_) => new_tokens.push(tok)
        None => {
          let tok = @lexer.dummy_long(0, raw="0")
          new_tokens.push(tok)
        }
      }
      continue rest
    }
    [tok, .. rest] => {
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
    [{ kind: Hash, .. }, { kind: Keyword(If), .. }, .. rest] =>
      continue skip_cond_incl2(rest)
    [{ kind: Hash, .. }, { kind: Identifier("ifdef" | "ifndef"), .. }, .. rest] =>
      continue skip_cond_incl2(rest)
    [{ kind: Hash, .. }, { kind: Identifier("elif" | "endif"), .. }, ..] as tokens =>
      break tokens
    [{ kind: Hash, .. }, { kind: Keyword(Else), .. }, ..] as tokens =>
      break tokens
    [_, .. rest] => continue rest
    [] as tokens => break tokens
  }
}

///|
fn skip_cond_incl2(tokens : ArrayView[Token]) -> ArrayView[Token] {
  loop tokens {
    [{ kind: Hash, .. }, { kind: Keyword(If), .. }, .. rest] =>
      continue skip_cond_incl2(rest)
    [{ kind: Hash, .. }, { kind: Identifier("ifdef" | "ifndef"), .. }, .. rest] =>
      continue skip_cond_incl2(rest)
    [{ kind: Hash, .. }, { kind: Identifier("endif"), .. }, .. rest] =>
      break rest
    [_, .. rest] => continue rest
    [] as tokens => break tokens
  }
}

///|
///
/// some macro may follow extra tokens like `#pragma once abcd` (`abcd` is extra, but not error, just ignore them)
fn skip_line(line : Int, tokens : ArrayView[Token]) -> ArrayView[Token] {
  loop tokens {
    [tok, .. rest] if tok.line == line => continue rest
    tokens => break tokens
  }
}

///|
fn replace_identifier(
  code : StringView,
  id_tok : Token,
  id : String,
  rest_tokens : ArrayView[Token],
) -> (Array[Token], ArrayView[Token]) raise PreprecessError {
  let cmacro = macros.get(id).unwrap()
  let saved = macros.get(id)
  macros.remove(id)
  if cmacro is ObjLike(toks) {
    let rescanned = expand_macro_for_tokens(code, toks)
    if saved is Some(m) {
      macros.set(id, m)
    }
    let filtered = strip_attribute_tokens(rescanned)
    return (filtered, rest_tokens)
  }
  guard cmacro is FuncLike(params, va_args, rep_toks)
  guard rest_tokens is [{ kind: Bracket('('), .. }, .. rest_after_paren] else {
    // Function-like macro not invoked; keep identifier as-is.
    if saved is Some(m) {
      macros.set(id, m)
    }
    return ([id_tok], rest_tokens)
  }
  let new_tokens : Array[Token] = Array::new()
  let mut paren_count = 0
  let mut brace_count = 0
  let mut bracket_count = 0
  let mut param_idx = 0
  let args : Map[String, Array[Token]] = Map::new()
  let mut current_arg_tokens : Array[Token] = Array::new()
  let va_args_tokens : Array[Token] = Array::new()
  let rest = loop rest_after_paren {
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
  let args_expanded : Map[String, Array[Token]] = Map::new()
  for p in params {
    match args.get(p) {
      Some(v) => args_expanded.set(p, expand_macro_for_tokens(code, v))
      None => ()
    }
  }
  if va_args is Some(va_name) {
    match args.get(va_name) {
      Some(v) => args_expanded.set(va_name, expand_macro_for_tokens(code, v))
      None => ()
    }
  }
  if id == "__builtin_expect" {
    match args.get("x") {
      Some(arg_tokens) => {
        if saved is Some(m) {
          macros.set(id, m)
        }
        return (arg_tokens, rest)
      }
      None => {
        if saved is Some(m) {
          macros.set(id, m)
        }
        return ([], rest)
      }
    }
  }
  // Expand replacement list with # and ## handling.
  let mut i = 0
  while i < rep_toks.length() {
    let tok = rep_toks[i]
    // Stringizing: `#param` uses raw (unexpanded) tokens.
    if tok.kind is Hash && i + 1 < rep_toks.length() {
      let next = rep_toks[i + 1]
      match next.kind {
        Identifier(var_name) if args.get(var_name) is Some(arg_tokens) => {
          let s = stringize_macro_arg(code, arg_tokens).to_string()
          new_tokens.push(@lexer.string_token_like(tok, s))
          i = i + 2
          continue
        }
        _ => ()
      }
    }
    // Token pasting: `a ## b` (supports chained pastes)
    if i + 2 < rep_toks.length() && rep_toks[i + 1].kind is Hash2 {
      let mut j = i
      let mut cur_tokens = match rep_toks[j].kind {
        Identifier(var_name) if args.get(var_name) is Some(arg_tokens) => arg_tokens
        _ => [rep_toks[j]]
      }
      while j + 1 < rep_toks.length() && rep_toks[j + 1].kind is Hash2 {
        let right_tok = rep_toks[j + 2]
        let right_tokens = match right_tok.kind {
          Identifier(var_name) if args.get(var_name) is Some(arg_tokens) => arg_tokens
          _ => [right_tok]
        }
        if cur_tokens.length() == 0 {
          cur_tokens = right_tokens
          j = j + 2
          continue
        }
        if right_tokens.length() == 0 {
          j = j + 2
          continue
        }
        let left_keep : Array[Token] = Array::new()
        let right_keep : Array[Token] = Array::new()
        let mut k = 0
        while k + 1 < cur_tokens.length() {
          left_keep.push(cur_tokens[k])
          k = k + 1
        }
        k = 1
        while k < right_tokens.length() {
          right_keep.push(right_tokens[k])
          k = k + 1
        }
        let left_last = cur_tokens[cur_tokens.length() - 1]
        let right_first = right_tokens[0]
        let merged_raw = left_last.raw + right_first.raw
        let lex_ctx = @lexer.Context::new(
          code=merged_raw,
          source_file=left_last.source_file,
        )
        let _ = lex_ctx.tokenize()
        let merged_tok = lex_ctx.tokens[0]
        let merged = @lexer.token_like(left_last, merged_tok.kind, raw=merged_raw)
        let merged_tokens : Array[Token] = Array::new()
        merged_tokens.append(left_keep)
        merged_tokens.push(merged)
        merged_tokens.append(right_keep)
        cur_tokens = merged_tokens
        j = j + 2
      }
      new_tokens.append(cur_tokens)
      i = j + 1
      continue
    }
    // Normal parameter substitution (use expanded tokens).
    match tok.kind {
      Identifier(var_name) if args_expanded.get(var_name) is Some(arg_tokens) => {
        new_tokens.append(arg_tokens)
      }
      _ => new_tokens.push(tok)
    }
    i = i + 1
  }
  let rescanned = expand_macro_for_tokens(code, new_tokens)
  if saved is Some(m) {
    macros.set(id, m)
  }
  let filtered = strip_attribute_tokens(rescanned)
  // If a function-like macro name is produced and immediately followed by '('
  // in the remaining tokens (e.g. CAT(A,B)(x)), expand it with the following tokens.
  if filtered.length() > 0 && rest is [{ kind: Bracket('('), .. }, ..] {
    let last = filtered[filtered.length() - 1]
    match last.kind {
      Identifier(name) if name != id && macros.get(name) is Some(FuncLike(_, _, _)) => {
        let prefix : Array[Token] = Array::new()
        let mut i = 0
        while i + 1 < filtered.length() {
          prefix.push(filtered[i])
          i = i + 1
        }
        let (expanded, rest2) = replace_identifier(code, last, name, rest)
        prefix.append(expanded)
        return (prefix, rest2)
      }
      _ => ()
    }
  }
  (filtered, rest)
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
  inspect(
    tokens[2].kind,
    content=(
      #|"Hello"
    ),
  )
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
  inspect(
    tokens[2].kind,
    content=(
      #|"Value: %d"
    ),
  )
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
  inspect(
    tokens[2].kind,
    content=(
      #|"Values: %d %d"
    ),
  )
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

///|
test "Conditional Inclusion - #if with true condition" {
  let code =
    #|#if 1
    #|int x = 42;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include: int x = 42;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="42")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #if with false condition" {
  let code =
    #|#if 0
    #|int x = 42;
    #|#endif
    #|int y = 99;
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should skip x and only include: int y = 99;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="y")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="99")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #ifdef with defined macro" {
  let code =
    #|#define DEBUG
    #|#ifdef DEBUG
    #|int x = 1;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include: int x = 1;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #ifdef with undefined macro" {
  let code =
    #|#ifdef UNDEFINED
    #|int x = 1;
    #|#endif
    #|int y = 2;
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should skip x and only include: int y = 2;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="y")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #ifndef with undefined macro" {
  let code =
    #|#ifndef UNDEFINED
    #|int x = 1;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include: int x = 1;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #ifndef with defined macro" {
  let code =
    #|#define DEBUG
    #|#ifndef DEBUG
    #|int x = 1;
    #|#endif
    #|int y = 2;
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should skip x and only include: int y = 2;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="y")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #if #else with true condition" {
  let code =
    #|#if 1
    #|int x = 1;
    #|#else
    #|int x = 2;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 1
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #if #else with false condition" {
  let code =
    #|#if 0
    #|int x = 1;
    #|#else
    #|int x = 2;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 2
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #if #elif with first true" {
  let code =
    #|#if 1
    #|int x = 1;
    #|#elif 1
    #|int x = 2;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 1
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #if #elif with elif true" {
  let code =
    #|#if 0
    #|int x = 1;
    #|#elif 1
    #|int x = 2;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 2
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - #if #elif #else chain" {
  let code =
    #|#if 0
    #|int x = 1;
    #|#elif 0
    #|int x = 2;
    #|#else
    #|int x = 3;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 3
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="3")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - Multiple #elif" {
  let code =
    #|#if 0
    #|int x = 1;
    #|#elif 0
    #|int x = 2;
    #|#elif 1
    #|int x = 3;
    #|#elif 1
    #|int x = 4;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 3 (first true elif)
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="3")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - defined operator with parentheses" {
  let code =
    #|#define FOO
    #|#if defined(FOO)
    #|int x = 1;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include: int x = 1;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - defined operator without parentheses" {
  let code =
    #|#define BAR
    #|#if defined BAR
    #|int y = 2;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include: int y = 2;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="y")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - defined operator for undefined macro" {
  let code =
    #|#if defined(UNDEFINED)
    #|int x = 1;
    #|#else
    #|int x = 2;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include: int x = 2;
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - nested conditions outer true" {
  let code =
    #|#if 1
    #|int a = 1;
    #|#if 1
    #|int b = 2;
    #|#endif
    #|int c = 3;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include all three
  inspect(tokens.length(), content="16")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[5].kind, content="int")
  inspect(tokens[6].kind, content="b")
  inspect(tokens[10].kind, content="int")
  inspect(tokens[11].kind, content="c")
}

///|
test "Conditional Inclusion - nested conditions outer false" {
  let code =
    #|#if 0
    #|int a = 1;
    #|#if 1
    #|int b = 2;
    #|#endif
    #|int c = 3;
    #|#endif
    #|int d = 4;
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should only include: int d = 4;
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="c")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="3")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - nested conditions inner false" {
  let code =
    #|#if 1
    #|int a = 1;
    #|#if 0
    #|int b = 2;
    #|#endif
    #|int c = 3;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include a and c, skip b
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[5].kind, content="int")
  inspect(tokens[6].kind, content="c")
}

///|
test "Conditional Inclusion - expression evaluation" {
  let code =
    #|#if 2 + 3 > 4
    #|int x = 1;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // 2 + 3 = 5 > 4 is true
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
}

///|
test "Conditional Inclusion - complex expression" {
  let code =
    #|#if (10 - 5) * 2 == 10
    #|int result = 1;
    #|#else
    #|int result = 0;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // (10 - 5) * 2 = 10, so condition is true
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="result")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - macro expansion within conditional block" {
  let code =
    #|#define VALUE 42
    #|#if 1
    #|int x = VALUE;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should expand VALUE to 42
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="42")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - undef and ifdef interaction" {
  let code =
    #|#define FOO
    #|#ifdef FOO
    #|int a = 1;
    #|#endif
    #|#undef FOO
    #|#ifdef FOO
    #|int b = 2;
    #|#else
    #|int c = 3;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include a = 1 and c = 3, but not b = 2
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  // Check for c = 3
  inspect(tokens[6].kind, content="c")
  inspect(tokens[7].kind, content="=")
  inspect(tokens[8].kind, content="3")
  inspect(tokens[9].kind, content=";")
}

///|
test "Conditional Inclusion - logical operators in expressions" {
  let code =
    #|#if 1 && 1
    #|int a = 1;
    #|#endif
    #|#if 1 && 0
    #|int b = 2;
    #|#endif
    #|#if 0 || 1
    #|int c = 3;
    #|#endif
    #|#if 0 || 0
    #|int d = 4;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include a = 1 and c = 3, but not b = 2 or d = 4
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[5].kind, content="int")
  inspect(tokens[6].kind, content="c")
}

///|
test "Conditional Inclusion - bitwise operators in expressions" {
  let code =
    #|#if (5 & 3) == 1
    #|int a = 1;
    #|#endif
    #|#if (5 | 3) == 7
    #|int b = 2;
    #|#endif
    #|#if (5 ^ 3) == 6
    #|int c = 3;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // 5 & 3 = 1, 5 | 3 = 7, 5 ^ 3 = 6, all true
  inspect(tokens.length(), content="16")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[5].kind, content="int")
  inspect(tokens[6].kind, content="b")
  inspect(tokens[10].kind, content="int")
  inspect(tokens[11].kind, content="c")
}

///|
test "Conditional Inclusion - comparison operators" {
  let code =
    #|#if 5 > 3
    #|int a = 1;
    #|#endif
    #|#if 3 < 5
    #|int b = 2;
    #|#endif
    #|#if 5 >= 5
    #|int c = 3;
    #|#endif
    #|#if 3 <= 5
    #|int d = 4;
    #|#endif
    #|#if 5 != 3
    #|int e = 5;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // All conditions are true
  inspect(tokens.length(), content="26")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[5].kind, content="int")
  inspect(tokens[6].kind, content="b")
  inspect(tokens[10].kind, content="int")
  inspect(tokens[11].kind, content="c")
  inspect(tokens[15].kind, content="int")
  inspect(tokens[16].kind, content="d")
  inspect(tokens[20].kind, content="int")
  inspect(tokens[21].kind, content="e")
}

///|
test "Conditional Inclusion - empty blocks" {
  let code =
    #|#if 1
    #|#endif
    #|int x = 1;
    #|#if 0
    #|#else
    #|#endif
    #|int y = 2;
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include x = 1 and y = 2, with empty blocks properly handled
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="x")
  inspect(tokens[6].kind, content="y")
  inspect(tokens[7].kind, content="=")
  inspect(tokens[8].kind, content="2")
  inspect(tokens[9].kind, content=";")
}

///|
test "Conditional Inclusion - complex nested with elif" {
  let code =
    #|#if 1
    #|  #if 0
    #|    int a = 1;
    #|  #elif 1
    #|    int b = 2;
    #|  #endif
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include b = 2
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="b")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="2")
  inspect(tokens[4].kind, content=";")
}

///|
test "Conditional Inclusion - negation operator" {
  let code =
    #|#if !0
    #|int a = 1;
    #|#endif
    #|#if !1
    #|int b = 2;
    #|#endif
    #|#if !(5 == 3)
    #|int c = 3;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // Should include a = 1 and c = 3 but not b = 2
  inspect(tokens.length(), content="11")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="a")
  inspect(tokens[5].kind, content="int")
  inspect(tokens[6].kind, content="c")
}

///|
test "Conditional Inclusion - mixed defined and expressions" {
  let code =
    #|#define FOO 5
    #|#define BAR 3
    #|#if defined(FOO) && defined(BAR) && (FOO > BAR)
    #|int result = 1;
    #|#else
    #|int result = 0;
    #|#endif
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens

  // All conditions are true
  inspect(tokens.length(), content="6")
  inspect(tokens[0].kind, content="int")
  inspect(tokens[1].kind, content="result")
  inspect(tokens[2].kind, content="=")
  inspect(tokens[3].kind, content="1")
  inspect(tokens[4].kind, content=";")
}

///|
test "Macro stringizing (#param) basic" {
  let code =
    #|#define S(x) #x
    #|S(1+2)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  // Should expand to string literal "1+2"
  inspect(tokens.length(), content="2")
  inspect(
    tokens[0].kind,
    content=(
      #|"1+2"
    ),
  )
}

///|
test "Macro stringizing (#param) for ASSERT-style macro" {
  let code =
    #|#define ASSERT(x, y) assert(x, y, #y)
    #|ASSERT(3, 1+2)
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  // assert(3, 1+2, "1+2")
  inspect(tokens[0].kind, content="assert")
  inspect(tokens[1].kind, content="(")
  inspect(tokens[2].kind, content="3")
  inspect(tokens[3].kind, content=",")
  inspect(tokens[4].kind, content="1")
  inspect(tokens[5].kind, content="+")
  inspect(tokens[6].kind, content="2")
  inspect(tokens[7].kind, content=",")
  inspect(
    tokens[8].kind,
    content=(
      #|"1+2"
    ),
  )
  inspect(tokens[9].kind, content=")")
}

///|
test "Macro stringizing escapes quotes and backslashes" {
  let code =
    #|#define S(x) #x
    #|S("a\\b\"c")
  let ctx = @lexer.Context::new(code~, source_file="demo.c")
  let _ = ctx.tokenize()
  let pre_ctx = preprocess(ctx)
  let tokens = pre_ctx.tokens
  // Expect the resulting string literal content to have \" and \\ escaped.
  inspect(tokens.length(), content="2")
  inspect(
    tokens[0].kind,
    content=(
      #|"\"a\\\\b\\\"c\""
    ),
  )
}
