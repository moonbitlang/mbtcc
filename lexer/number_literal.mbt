///|
fn Context::lex_number_literal(
  self : Self,
  code : StringView,
  source_file : String,
  line : Int,
  col : Int,
  idx : Int,
) -> (Token, StringView) {
  fn parse_u64_base(s : StringView, base : UInt) -> (UInt64, String) {
    let mut acc : UInt64 = 0UL
    for c in s {
      let digit : UInt? = match c {
        '0'..='9' => Some((c.to_int() - '0'.to_int()).reinterpret_as_uint())
        'a'..='f' =>
          Some((c.to_int() - 'a'.to_int() + 10).reinterpret_as_uint())
        'A'..='F' =>
          Some((c.to_int() - 'A'.to_int() + 10).reinterpret_as_uint())
        _ => None
      }
      guard digit is Some(d) else {
        return (0UL, "Invalid digit in integer literal")
      }
      if d >= base {
        return (0UL, "Invalid digit in integer literal")
      }
      let b = base.to_uint64()
      let d64 = d.to_uint64()
      if acc > (0xffffffffffffffffUL - d64) / b {
        return (0UL, "Integer literal overflow")
      }
      acc = acc * b + d64
    }
    (acc, "")
  }

  lexmatch code with longest {
    // Case 1. Hexadecimal floating-point literal
    (
      "0[xX]"
      ("([0-9a-fA-F]+\.?[0-9a-fA-F]*|\.[0-9a-fA-F]+)[pP][\+\-]?[0-9]+" as hf)
      ("[fFlL]?" as s),
      rest
    ) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(hf.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      println("Hex float literal: '\{hf}'")
      let (number, err_msg) = try @strconv.parse_double(hf) catch {
        _ => (0.0, "Invalid hexadecimal floating-point literal")
      } noraise {
        n => (n, "")
      }
      let token_kind = match s {
        "f" | "F" => TokenKind::Float(Float::from_double(number))
        _ => TokenKind::Double(number)
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 2-1. Decimal floating-point literal with decimal point
    (
      ("([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)([eE][\+\-]?[0-9]+)?" as df_dot)
      ("[fFlL]?" as s),
      rest
    ) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(df_dot.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = try @strconv.parse_double(df_dot) catch {
        _ => (0.0, "Invalid decimal floating-point literal")
      } noraise {
        n => (n, "")
      }
      let token_kind = match s {
        "f" | "F" => TokenKind::Float(Float::from_double(number))
        _ => TokenKind::Double(number)
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 2-2: Decimal floating-point literal with exponent
    (("[0-9]+[eE][\+\-]?[0-9]+" as df_exp) ("[fFlL]?" as s), rest) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(df_exp.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number, err_msg) = try @strconv.parse_double(df_exp) catch {
        _ => (0.0, "Invalid decimal floating-point literal")
      } noraise {
        n => (n, "")
      }
      let token_kind = match s {
        "f" | "F" => TokenKind::Float(Float::from_double(number))
        _ => TokenKind::Double(number)
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 3. Hexadecimal integer literal
    (
      "0[xX]"
      ("[0-9a-fA-F]+" as h)
      ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s),
      rest
    ) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string("0x")
      raw_str_builder.write_string(h.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number64, err_msg) = parse_u64_base(h, 16U)
      let token_kind = match s.to_lower() {
        "ull" | "llu" | "ULL" | "LLU" => TokenKind::ULongLong(number64)
        "ul" | "lu" | "UL" | "LU" => TokenKind::ULong(number64)
        "ll" | "LL" => TokenKind::LongLong(number64.reinterpret_as_int64())
        "u" | "U" => TokenKind::UInt(number64.to_uint())
        "l" | "L" => TokenKind::Long(number64.reinterpret_as_int64())
        _ => TokenKind::Int(number64.to_uint().reinterpret_as_int())
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 4. Binary integer literal
    (
      "0[bB]"
      ("[01]+" as b)
      ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s),
      rest
    ) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string("0b")
      raw_str_builder.write_string(b.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number64, err_msg) = parse_u64_base(b, 2U)
      let token_kind = match s.to_lower() {
        "ull" | "llu" | "ULL" | "LLU" => TokenKind::ULongLong(number64)
        "ul" | "lu" | "UL" | "LU" => TokenKind::ULong(number64)
        "ll" | "LL" => TokenKind::LongLong(number64.reinterpret_as_int64())
        "u" | "U" => TokenKind::UInt(number64.to_uint())
        "l" | "L" => TokenKind::Long(number64.reinterpret_as_int64())
        _ => TokenKind::Int(number64.to_uint().reinterpret_as_int())
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 5. Octal integer literal
    (
      ("0[0-7]+" as o)
      ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s),
      rest
    ) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(o.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number64, err_msg) = parse_u64_base(o, 8U)
      let token_kind = match s.to_lower() {
        "ull" | "llu" | "ULL" | "LLU" => TokenKind::ULongLong(number64)
        "ul" | "lu" | "UL" | "LU" => TokenKind::ULong(number64)
        "ll" | "LL" => TokenKind::LongLong(number64.reinterpret_as_int64())
        "u" | "U" => TokenKind::UInt(number64.to_uint())
        "l" | "L" => TokenKind::Long(number64.reinterpret_as_int64())
        _ => TokenKind::Int(number64.to_uint().reinterpret_as_int())
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    // Case 6. Decimal integer literal
    (
      ("([1-9][0-9]*|0)" as d)
      ("(ull|ULL|llu|LLU|ul|UL|lu|LU|ll|LL|u|U|l|L)?" as s),
      rest
    ) => {
      let raw_str_builder = StringBuilder::new()
      raw_str_builder.write_string(d.to_string())
      raw_str_builder.write_string(s.to_string())
      let raw_str = raw_str_builder.to_string()
      let (number64, err_msg) = parse_u64_base(d, 10U)
      let token_kind = match s.to_lower() {
        "ull" | "llu" | "ULL" | "LLU" => TokenKind::ULongLong(number64)
        "ul" | "lu" | "UL" | "LU" => TokenKind::ULong(number64)
        "ll" | "LL" => TokenKind::LongLong(number64.reinterpret_as_int64())
        "u" | "U" => TokenKind::UInt(number64.to_uint())
        "l" | "L" => TokenKind::Long(number64.reinterpret_as_int64())
        _ => TokenKind::Int(number64.to_uint().reinterpret_as_int())
      }
      let token = Token::new(token_kind, source_file, line, col, idx, raw_str)
      if !err_msg.is_empty() {
        self.err_toks.push(token)
      }
      (token, rest)
    }
    _ => abort("")
  }
}
