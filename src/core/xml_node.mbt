// 一个只覆盖 KML 需要的最小 XML 解析器。
//
// KML 文档是 XML 的一个方言：元素、属性、文本、CDATA、注释、处理指令与实体引用
// 就够用，不需要 DTD 实体展开或命名空间解析。这里按字节扫描，避免把 UTF-8
// 文本按字符索引带来的边界问题。

///|
/// 一个 XML 属性。
pub(all) struct XmlAttr {
  name : String
  value : String
}

///|
/// XML 节点：元素或文本。
pub(all) enum XmlNode {
  Element(XmlElement)
  Text(String)
}

///|
/// 一个 XML 元素。
pub(all) struct XmlElement {
  name : String
  attrs : Array[XmlAttr]
  children : Array[XmlNode]
}

///|
/// 读取元素上第一个同名属性，没有则返回 None。
pub fn XmlElement::attr(self : XmlElement, name : String) -> String? {
  let mut i = 0
  while i < self.attrs.length() {
    if self.attrs[i].name == name {
      return Some(self.attrs[i].value)
    }
    i = i + 1
  }
  None
}

///|
/// 子元素中第一个同名的元素。
pub fn XmlElement::child(self : XmlElement, name : String) -> XmlElement? {
  let mut i = 0
  while i < self.children.length() {
    match self.children[i] {
      Element(e) => if e.name == name { return Some(e) }
      Text(_) => ()
    }
    i = i + 1
  }
  None
}

///|
/// 直接文本子节点拼接后的内容（不含子元素内部的文本）。
pub fn XmlElement::text(self : XmlElement) -> String {
  let out : Array[Byte] = []
  let mut i = 0
  while i < self.children.length() {
    match self.children[i] {
      Text(t) => {
        let encoded = @utf8.encode(t)
        let mut k = 0
        while k < encoded.length() {
          out.push(encoded[k])
          k = k + 1
        }
      }
      Element(_) => ()
    }
    i = i + 1
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

///|
/// 该字节是否是空白。

///|
/// 找第一个同名子元素。
pub fn first_element(elem : XmlElement, name : String) -> XmlElement? {
  elem.child(name)
}

///|
/// 取同名子元素的文本；没有则返回 None。
pub fn child_text(elem : XmlElement, name : String) -> String? {
  match elem.child(name) {
    Some(c) => Some(trim_text(c.text()))
    None => None
  }
}
