// 文本工具：KML 里空白与逗号的分隔规则。

///|
pub fn is_space(b : Byte) -> Bool {
  b == b' ' || b == b'\t' || b == b'\n' || b == b'\r'
}

///|
pub fn trim_text(text : String) -> String {
  let data = @utf8.encode(text)
  let mut start = 0
  let mut end = data.length()
  while start < end && is_space(data[start]) {
    start = start + 1
  }
  while end > start && is_space(data[end - 1]) {
    end = end - 1
  }
  @utf8.decode_lossy(data.clamped_view(start~, end~))
}

///|
pub fn split_commas(text : String) -> Array[String] {
  let data = @utf8.encode(text)
  let out : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i < data.length() {
    if data[i] == b',' {
      out.push(trim_text(@utf8.decode_lossy(data.clamped_view(start~, end=i))))
      start = i + 1
    }
    i = i + 1
  }
  out.push(
    trim_text(@utf8.decode_lossy(data.clamped_view(start~, end=data.length()))),
  )
  out
}

///|
pub fn split_whitespace(text : String) -> Array[String] {
  let data = @utf8.encode(text)
  let out : Array[String] = []
  let mut i = 0
  let n = data.length()
  while i < n {
    while i < n && is_space(data[i]) {
      i = i + 1
    }
    if i >= n {
      break
    }
    let start = i
    while i < n && !is_space(data[i]) {
      i = i + 1
    }
    out.push(@utf8.decode_lossy(data.clamped_view(start~, end=i)))
  }
  out
}
