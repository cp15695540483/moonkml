// KML 序列化：把文档模型转回 KML 文本。
//
// 输出带 XML 声明、kml 根与命名空间、Document；文本做 XML 转义。
// 这是读写闭环的一半，round-trip 测试会用它配合 parse。

///|
/// 追加一段文本的 XML 转义结果到字节数组。
fn push_escaped(out : Array[Byte], text : String) -> Unit {
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
/// 追加字面量字符串的 UTF-8 字节。
fn push_lit(out : Array[Byte], text : String) -> Unit {
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() {
    out.push(data[i])
    i = i + 1
  }
}

///|
/// 追加换行。
fn push_newline(out : Array[Byte]) -> Unit {
  out.push(b'\n')
}

///|
/// 序列化一个坐标点。
fn push_point_coords(out : Array[Byte], p : KmlPoint) -> Unit {
  push_double(out, p.lon)
  out.push(b',')
  push_double(out, p.lat)
  match p.alt {
    Some(a) => {
      out.push(b',')
      push_double(out, a)
    }
    None => ()
  }
}

///|
/// 追加双精度浮点：用最短可往返的 to_string。
fn push_double(out : Array[Byte], value : Double) -> Unit {
  push_lit(out, value.to_string())
}

///|
/// 序列化一个点列（LineString 或 LinearRing 共用）。
fn push_points(out : Array[Byte], points : Array[KmlPoint]) -> Unit {
  let mut i = 0
  while i < points.length() {
    push_point_coords(out, points[i])
    if i + 1 < points.length() {
      push_lit(out, " ")
    }
    i = i + 1
  }
}

///|
/// 序列化 Point。
fn serialize_point(out : Array[Byte], p : KmlPoint) -> Unit {
  push_lit(out, "<Point><coordinates>")
  push_point_coords(out, p)
  push_lit(out, "</coordinates></Point>")
}

///|
/// 序列化 LineString。
fn serialize_line_string(out : Array[Byte], ls : KmlLineString) -> Unit {
  push_lit(out, "<LineString><coordinates>")
  push_points(out, ls.points)
  push_lit(out, "</coordinates></LineString>")
}

///|
/// 序列化 LinearRing。
fn serialize_ring(out : Array[Byte], ring : LinearRing) -> Unit {
  push_lit(out, "<LinearRing><coordinates>")
  push_points(out, ring.points)
  push_lit(out, "</coordinates></LinearRing>")
}

///|
/// 序列化 Polygon。
fn serialize_polygon(out : Array[Byte], poly : KmlPolygon) -> Unit {
  push_lit(out, "<Polygon><outerBoundaryIs>")
  serialize_ring(out, poly.outer)
  push_lit(out, "</outerBoundaryIs>")
  let mut i = 0
  while i < poly.inner.length() {
    push_lit(out, "<innerBoundaryIs>")
    serialize_ring(out, poly.inner[i])
    push_lit(out, "</innerBoundaryIs>")
    i = i + 1
  }
  push_lit(out, "</Polygon>")
}

///|
/// 序列化一个 Placemark。
fn serialize_placemark(out : Array[Byte], pm : Placemark) -> Unit {
  push_lit(out, "<Placemark>")
  if pm.name != "" {
    push_lit(out, "<name>")
    push_escaped(out, pm.name)
    push_lit(out, "</name>")
  }
  if pm.description != "" {
    push_lit(out, "<description>")
    push_escaped(out, pm.description)
    push_lit(out, "</description>")
  }
  match pm.geometry {
    Some(Geometry::Point(p)) => serialize_point(out, p)
    Some(Geometry::LineString(ls)) => serialize_line_string(out, ls)
    Some(Geometry::Polygon(poly)) => serialize_polygon(out, poly)
    None => ()
  }
  push_lit(out, "</Placemark>")
}

///|
/// 把 KML 文档序列化成文本。
pub fn serialize(doc : KmlDocument) -> String {
  let out : Array[Byte] = []
  push_lit(out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  push_newline(out)
  push_lit(out, "<kml xmlns=\"http://www.opengis.net/kml/2.2\">")
  push_newline(out)
  push_lit(out, "<Document>")
  if doc.name != "" {
    push_newline(out)
    push_lit(out, "<name>")
    push_escaped(out, doc.name)
    push_lit(out, "</name>")
  }
  let mut i = 0
  while i < doc.placemarks.length() {
    push_newline(out)
    serialize_placemark(out, doc.placemarks[i])
    i = i + 1
  }
  push_newline(out)
  push_lit(out, "</Document>")
  push_newline(out)
  push_lit(out, "</kml>")
  @utf8.decode_lossy(Bytes::from_array(out))
}
