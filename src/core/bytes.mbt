// 字节输出基元：KML / GeoJSON / GPX 三种输出共用。

///|
pub fn push_lit(out : Array[Byte], text : String) -> Unit {
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() {
    out.push(data[i])
    i = i + 1
  }
}

///|
pub fn push_escaped(out : Array[Byte], text : String) -> Unit {
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() {
    let b = data[i]
    if b == b'&' {
      push_lit(out, "&amp;")
    } else if b == b'<' {
      push_lit(out, "&lt;")
    } else if b == b'>' {
      push_lit(out, "&gt;")
    } else if b == b'"' {
      push_lit(out, "&quot;")
    } else if b == b'\'' {
      push_lit(out, "&apos;")
    } else {
      out.push(b)
    }
    i = i + 1
  }
}

///|
pub fn push_newline(out : Array[Byte]) -> Unit {
  out.push(b'\n')
}

///|
pub fn push_double(out : Array[Byte], value : Double) -> Unit {
  push_lit(out, value.to_string())
}
