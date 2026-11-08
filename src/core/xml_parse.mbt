// XML 子集解析器：元素、属性、文本、CDATA、注释、处理指令、实体引用。

///|
/// 该字节是否可以出现在元素名或属性名里（KML 只用 ASCII 名字）。
fn is_name_byte(b : Byte) -> Bool {
  (b >= b'a' && b <= b'z') ||
  (b >= b'A' && b <= b'Z') ||
  (b >= b'0' && b <= b'9') ||
  b == b'_' ||
  b == b':' ||
  b == b'-' ||
  b == b'.'
}

///|
/// 从 at 起是否与字面量字面一致。
fn at_is(data : Bytes, at : Int32, lit : Bytes) -> Bool {
  if at + lit.length() > data.length() {
    return false
  }
  let mut i = 0
  while i < lit.length() {
    if data[at + i] != lit[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 从 from 起查找字面量，返回起始下标。
fn find_lit(data : Bytes, from : Int32, lit : Bytes) -> Int32? {
  let n = data.length()
  let mut i = from
  while i + lit.length() <= n {
    if at_is(data, i, lit) {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// 跳过空白。
fn skip_space(data : Bytes, from : Int32) -> Int32 {
  let n = data.length()
  let mut i = from
  while i < n && is_space(data[i]) {
    i = i + 1
  }
  i
}

///|
/// 读一个名字，返回名字与其后位置。
fn read_name(data : Bytes, from : Int32) -> (String, Int32) raise KmlError {
  let n = data.length()
  let mut i = from
  while i < n && is_name_byte(data[i]) {
    i = i + 1
  }
  if i == from {
    raise XmlSyntax("expected a name", from)
  }
  (@utf8.decode_lossy(data.clamped_view(start=from, end=i)), i)
}

///|
/// ASCII 十六进制数字的值，非数字返回 -1。

///|
/// 十进制数字的值，非数字返回 -1。

///|
/// 把一个 Unicode 码点按 UTF-8 追加到字节数组。
fn push_codepoint(out : Array[Byte], cp : Int32) -> Unit {
  if cp < 0x80 {
    out.push(cp.to_byte())
  } else if cp < 0x800 {
    out.push((0xC0 | (cp >> 6)).to_byte())
    out.push((0x80 | (cp & 0x3F)).to_byte())
  } else if cp < 0x10000 {
    out.push((0xE0 | (cp >> 12)).to_byte())
    out.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    out.push((0x80 | (cp & 0x3F)).to_byte())
  } else {
    out.push((0xF0 | (cp >> 18)).to_byte())
    out.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
    out.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    out.push((0x80 | (cp & 0x3F)).to_byte())
  }
}

///|
/// 把实体名解析成码点：amp/lt/gt/quot/apos、&#NN;、&#xHH;。
fn entity_codepoint(name : BytesView) -> Int32? {
  let bytes = name.to_array()
  if bytes.length() == 0 {
    return None
  }
  if bytes[0] != b'#' {
    let text = @utf8.decode_lossy(name)
    return if text == "amp" {
      Some(38)
    } else if text == "lt" {
      Some(60)
    } else if text == "gt" {
      Some(62)
    } else if text == "quot" {
      Some(34)
    } else if text == "apos" {
      Some(39)
    } else {
      None
    }
  }
  let mut i = 1
  let mut value = 0
  if i < bytes.length() && (bytes[i] == b'x' || bytes[i] == b'X') {
    i = i + 1
    let mut digits = 0
    while i < bytes.length() {
      let d = hex_digit(bytes[i])
      if d < 0 {
        return None
      }
      value = value * 16 + d
      digits = digits + 1
      i = i + 1
    }
    if digits == 0 {
      return None
    }
  } else {
    let mut digits = 0
    while i < bytes.length() {
      let d = dec_digit(bytes[i])
      if d < 0 {
        return None
      }
      value = value * 10 + d
      digits = digits + 1
      i = i + 1
    }
    if digits == 0 {
      return None
    }
  }
  if value <= 0 || value > 0x10FFFF {
    return None
  }
  Some(value)
}

///|
/// 解码 [start, end) 区间：按需展开实体引用，未知实体原样保留。
fn decode_text(data : Bytes, start : Int32, end : Int32) -> String {
  let out : Array[Byte] = []
  let mut i = start
  while i < end {
    if data[i] == b'&' {
      let mut j = i + 1
      while j < end && data[j] != b';' && j - i <= 12 {
        j = j + 1
      }
      if j < end && data[j] == b';' && j > i + 1 {
        match entity_codepoint(data.clamped_view(start=i + 1, end=j)) {
          Some(cp) => {
            push_codepoint(out, cp)
            i = j + 1
          }
          None => {
            out.push(data[i])
            i = i + 1
          }
        }
      } else {
        out.push(data[i])
        i = i + 1
      }
    } else {
      out.push(data[i])
      i = i + 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

///|
/// 把已闭合的元素挂到父元素或根上。
fn attach(
  stack : Array[XmlElement],
  root : XmlElement?,
  elem : XmlElement,
  at : Int32,
) -> XmlElement? raise KmlError {
  if stack.length() > 0 {
    stack[stack.length() - 1].children.push(Element(elem))
    root
  } else if root is None {
    Some(elem)
  } else {
    raise XmlMultipleRoots(at)
  }
}

///|
/// 解析一个 XML 文档，返回根元素。
pub fn parse_xml(input : String) -> XmlElement raise KmlError {
  let data = @utf8.encode(input)
  let n = data.length()
  let stack : Array[XmlElement] = []
  let mut root : XmlElement? = None
  let mut i = 0
  while i < n {
    if data[i] == b'<' {
      if at_is(data, i, b"<!--") {
        match find_lit(data, i + 4, b"-->") {
          Some(end) => i = end + 3
          None => raise XmlSyntax("unterminated comment", i)
        }
      } else if at_is(data, i, b"<![CDATA[") {
        match find_lit(data, i + 9, b"]]>") {
          Some(end) => {
            if stack.length() > 0 {
              let text = @utf8.decode_lossy(
                data.clamped_view(start=i + 9, end~),
              )
              stack[stack.length() - 1].children.push(Text(text))
            }
            i = end + 3
          }
          None => raise XmlSyntax("unterminated CDATA", i)
        }
      } else if at_is(data, i, b"<?") {
        match find_lit(data, i + 2, b"?>") {
          Some(end) => i = end + 2
          None => raise XmlSyntax("unterminated processing instruction", i)
        }
      } else if at_is(data, i, b"<!") {
        match find_lit(data, i + 2, b">") {
          Some(end) => i = end + 1
          None => raise XmlSyntax("unterminated declaration", i)
        }
      } else if at_is(data, i, b"</") {
        let (name, after) = read_name(data, i + 2)
        let mut j = skip_space(data, after)
        if j >= n || data[j] != b'>' {
          raise XmlSyntax("expected > after end tag name", j)
        }
        j = j + 1
        match stack.pop() {
          Some(top) =>
            if top.name != name {
              raise XmlMismatch(top.name, name, i)
            } else {
              root = attach(stack, root, top, i)
            }
          None => raise XmlUnexpectedEnd(name, i)
        }
        i = j
      } else {
        let (name, after) = read_name(data, i + 1)
        let attrs : Array[XmlAttr] = []
        let mut j = after
        let mut done = false
        let mut self_closing = false
        while !done {
          j = skip_space(data, j)
          if j >= n {
            raise XmlSyntax("unterminated start tag", i)
          }
          if data[j] == b'>' {
            j = j + 1
            done = true
          } else if data[j] == b'/' {
            if j + 1 < n && data[j + 1] == b'>' {
              self_closing = true
              j = j + 2
              done = true
            } else {
              raise XmlSyntax("expected />", j)
            }
          } else {
            let (aname, after_name) = read_name(data, j)
            j = skip_space(data, after_name)
            if j >= n || data[j] != b'=' {
              raise XmlSyntax("expected = after attribute name", j)
            }
            j = skip_space(data, j + 1)
            if j >= n || (data[j] != b'"' && data[j] != b'\'') {
              raise XmlSyntax("expected quoted attribute value", j)
            }
            let quote = data[j]
            let vstart = j + 1
            let mut k = vstart
            while k < n && data[k] != quote {
              k = k + 1
            }
            if k >= n {
              raise XmlSyntax("unterminated attribute value", vstart)
            }
            attrs.push({ name: aname, value: decode_text(data, vstart, k), })
            j = k + 1
          }
        }
        let elem : XmlElement = { name, attrs, children: [], }
        if self_closing {
          root = attach(stack, root, elem, i)
        } else {
          stack.push(elem)
        }
        i = j
      }
    } else {
      let start = i
      let mut j = i
      while j < n && data[j] != b'<' {
        j = j + 1
      }
      if j > start && stack.length() > 0 {
        let text = decode_text(data, start, j)
        stack[stack.length() - 1].children.push(Text(text))
      }
      i = j
    }
  }
  if stack.length() > 0 {
    raise XmlUnclosed(stack[stack.length() - 1].name, n)
  }
  match root {
    Some(r) => r
    None => raise XmlMissingRoot
  }
}
