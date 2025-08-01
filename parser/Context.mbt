enum Type {
  Void   // void
  Int8
  Int16
  Int32
  Int64
  UInt8
  UInt16
  UInt32
  UInt64
  Float
  Double
  Bool // _Bool
  Struct(String?, Array[Type]) // Struct name and fields
  Union(String?, Array[Type]) // Union name and fields
}

struct Context {
  code: String
  alltoks: Array[Token]
  mut rest_toks: @array.View[Token]
  typedefs: Map[String, Type]
}

fn Context::create(code: String) -> Context {
  Context::{
    code: code,
    alltoks: Array::new(),
    rest_toks: [],
    typedefs: Map::new()
  }
}
