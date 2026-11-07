// KML 解析：把 XML 树转成 KmlDocument。
//
// 这一版只认 Document / Folder / Placemark / name / description / Point / coordinates，
// 其它元素一律忽略——KML 允许扩展元素，忽略比报错更符合实际数据。

///|
/// 收集过程中的中间状态。
priv struct Collector {
  mut document_name : String
  placemarks : Array[Placemark]
  styles : Array[KmlStyle]
}

///|
/// 去掉首尾空白。
fn trim_text(text : String) -> String {
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
/// 第一个同名子元素。
fn first_element(elem : XmlElement, name : String) -> XmlElement? {
  elem.child(name)
}

///|
/// 直接子元素的文本（去首尾空白）。
fn child_text(elem : XmlElement, name : String) -> String? {
  match elem.child(name) {
    Some(c) => Some(trim_text(c.text()))
    None => None
  }
}

///|
/// 解析一个十进制浮点数：符号、整数、小数、指数。
fn parse_double(text : String) -> Double? {
  let data = @utf8.encode(text)
  let n = data.length()
  let mut i = 0
  let mut negative = false
  if i < n && (data[i] == b'-' || data[i] == b'+') {
    negative = data[i] == b'-'
    i = i + 1
  }
  let mut mantissa = 0.0
  let mut seen = false
  while i < n && dec_digit(data[i]) >= 0 {
    mantissa = mantissa * 10.0 + digit_value(dec_digit(data[i]))
    seen = true
    i = i + 1
  }
  let mut fraction = 0
  if i < n && data[i] == b'.' {
    i = i + 1
    while i < n && dec_digit(data[i]) >= 0 {
      mantissa = mantissa * 10.0 + digit_value(dec_digit(data[i]))
      fraction = fraction + 1
      seen = true
      i = i + 1
    }
  }
  if !seen {
    return None
  }
  let mut exponent = 0
  if i < n && (data[i] == b'e' || data[i] == b'E') {
    i = i + 1
    let mut exp_negative = false
    if i < n && (data[i] == b'-' || data[i] == b'+') {
      exp_negative = data[i] == b'-'
      i = i + 1
    }
    let mut value = 0
    let mut digits = 0
    while i < n && dec_digit(data[i]) >= 0 {
      value = value * 10 + dec_digit(data[i])
      digits = digits + 1
      i = i + 1
    }
    if digits == 0 {
      return None
    }
    exponent = if exp_negative { -value } else { value }
  }
  if i != n {
    return None
  }
  // 单次除法 / 乘法而不是逐位缩放，避免多次舍入把结果推离最近的双精度值。
  let mut value = mantissa
  if fraction > 0 {
    let scale = pow10(fraction)
    value = value / scale
  }
  if exponent != 0 {
    let scale = pow10(if exponent < 0 { -exponent } else { exponent })
    if exponent > 0 {
      value = value * scale
    } else {
      value = value / scale
    }
  }
  Some(if negative { -value } else { value })
}

///|
/// 10 的 n 次幂（n <= 308），用循环累乘得到最近的双精度值。
fn pow10(n : Int32) -> Double {
  let mut value = 1.0
  let mut k = 0
  while k < n {
    value = value * 10.0
    k = k + 1
  }
  value
}

///|
/// 0..9 到 Double 的映射。
fn digit_value(digit : Int32) -> Double {
  match digit {
    0 => 0.0
    1 => 1.0
    2 => 2.0
    3 => 3.0
    4 => 4.0
    5 => 5.0
    6 => 6.0
    7 => 7.0
    8 => 8.0
    _ => 9.0
  }
}

///|
/// 按逗号切分坐标文本，逐段去空白。
fn split_commas(text : String) -> Array[String] {
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
/// 按任意空白或换行切分坐标元组文本，逐段去空白。
fn split_whitespace(text : String) -> Array[String] {
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

///|
/// 解析单个坐标文本「lon,lat[,alt]」。
fn parse_coordinate(text : String) -> KmlPoint raise KmlError {
  let parts = split_commas(text)
  if parts.length() < 2 || parts[0] == "" || parts[1] == "" {
    raise BadCoordinates(text)
  }
  let lon = parse_double(parts[0])
  let lat = parse_double(parts[1])
  let alt = if parts.length() >= 3 && parts[2] != "" {
    parse_double(parts[2])
  } else {
    None
  }
  match (lon, lat) {
    (Some(lon), Some(lat)) => { lon, lat, alt, }
    _ => raise BadCoordinates(text)
  }
}

///|
/// 解析 Placemark 里的 Point 几何；没有 Point 返回 None。
fn parse_point(elem : XmlElement) -> KmlPoint? raise KmlError {
  match first_element(elem, "Point") {
    None => None
    Some(point_elem) =>
      match first_element(point_elem, "coordinates") {
        None => raise MissingCoordinates
        Some(coords) => Some(parse_coordinate(trim_text(coords.text())))
      }
  }
}

///|
/// 解析 Placemark 里的 LineString 几何；没有 LineString 返回 None。
///
/// KML 允许用换行分隔坐标元组、空格分隔分量，两者都按任意空白切分。
fn parse_line_string(elem : XmlElement) -> KmlLineString? raise KmlError {
  match first_element(elem, "LineString") {
    None => None
    Some(ls_elem) =>
      match first_element(ls_elem, "coordinates") {
        None => raise MissingCoordinates
        Some(coords) => {
          let text = trim_text(coords.text())
          let tuples = split_whitespace(text)
          let points : Array[KmlPoint] = []
          let mut i = 0
          while i < tuples.length() {
            if tuples[i] != "" {
              points.push(parse_coordinate(tuples[i]))
            }
            i = i + 1
          }
          if points.length() == 0 {
            raise BadCoordinates(text)
          }
          Some({ points, })
        }
      }
  }
}

///|
/// 解析一个 LinearRing：coordinate 元组序列，首尾应闭合。
fn parse_ring(elem : XmlElement) -> LinearRing raise KmlError {
  match first_element(elem, "coordinates") {
    None => raise MissingCoordinates
    Some(coords) => {
      let text = trim_text(coords.text())
      let tuples = split_whitespace(text)
      let points : Array[KmlPoint] = []
      let mut i = 0
      while i < tuples.length() {
        if tuples[i] != "" {
          points.push(parse_coordinate(tuples[i]))
        }
        i = i + 1
      }
      if points.length() < 3 {
        raise BadCoordinates(text)
      }
      let ring : LinearRing = { points, }
      ring
    }
  }
}

///|
/// 解析一个 Polygon：outerBoundaryIs / innerBoundaryIs 里各一个 LinearRing。
fn parse_polygon(elem : XmlElement) -> KmlPolygon? raise KmlError {
  match first_element(elem, "Polygon") {
    None => None
    Some(poly) =>
      match first_element(poly, "outerBoundaryIs") {
        None => raise BadCoordinates("missing outerBoundaryIs")
        Some(outer_boundary) =>
          match first_element(outer_boundary, "LinearRing") {
            None => raise BadCoordinates("missing outer LinearRing")
            Some(outer_ring) => {
              let inner : Array[LinearRing] = []
              let mut i = 0
              while i < poly.children.length() {
                match poly.children[i] {
                  Element(inner_boundary) =>
                    if inner_boundary.name == "innerBoundaryIs" {
                      match first_element(inner_boundary, "LinearRing") {
                        Some(ring_elem) => inner.push(parse_ring(ring_elem))
                        None =>
                          raise BadCoordinates(
                            "innerBoundaryIs missing LinearRing",
                          )
                      }
                    }
                  Text(_) => ()
                }
                i = i + 1
              }
              Some({ outer: parse_ring(outer_ring), inner, })
            }
          }
      }
  }
}

///|
/// 把一个「几何元素本身」按名字解析成 Geometry。
///
/// 与 parse_point/parse_line_string/parse_polygon 不同：那些从 Placemark
/// 容器里找子元素，这里 elem 自己就是 Point/LineString/Polygon。
fn geometry_from_elem(elem : XmlElement) -> Geometry? raise KmlError {
  if elem.name == "Point" {
    match first_element(elem, "coordinates") {
      None => raise MissingCoordinates
      Some(coords) =>
        Some(Geometry::Point(parse_coordinate(trim_text(coords.text()))))
    }
  } else if elem.name == "LineString" {
    match first_element(elem, "coordinates") {
      None => raise MissingCoordinates
      Some(coords) => {
        let text = trim_text(coords.text())
        let tuples = split_whitespace(text)
        let points : Array[KmlPoint] = []
        let mut i = 0
        while i < tuples.length() {
          if tuples[i] != "" {
            points.push(parse_coordinate(tuples[i]))
          }
          i = i + 1
        }
        if points.length() == 0 {
          raise BadCoordinates(text)
        }
        Some(Geometry::LineString({ points, }))
      }
    }
  } else if elem.name == "Polygon" {
    match parse_polygon_container(elem) {
      Some(poly) => Some(Geometry::Polygon(poly))
      None => None
    }
  } else {
    None
  }
}

///|
/// 解析一个 Polygon 元素本身（不找子元素，elem 就是 Polygon）。
fn parse_polygon_container(elem : XmlElement) -> KmlPolygon? raise KmlError {
  match first_element(elem, "outerBoundaryIs") {
    None => raise BadCoordinates("missing outerBoundaryIs")
    Some(outer_boundary) =>
      match first_element(outer_boundary, "LinearRing") {
        None => raise BadCoordinates("missing outer LinearRing")
        Some(outer_ring) => {
          let inner : Array[LinearRing] = []
          let mut i = 0
          while i < elem.children.length() {
            match elem.children[i] {
              Element(inner_boundary) =>
                if inner_boundary.name == "innerBoundaryIs" {
                  match first_element(inner_boundary, "LinearRing") {
                    Some(ring_elem) => inner.push(parse_ring(ring_elem))
                    None =>
                      raise BadCoordinates("innerBoundaryIs missing LinearRing")
                  }
                }
              Text(_) => ()
            }
            i = i + 1
          }
          Some({ outer: parse_ring(outer_ring), inner, })
        }
      }
  }
}

///|
/// 解析 MultiGeometry：按出现顺序收集子几何。
fn parse_multi_geometry(elem : XmlElement) -> Array[Geometry]? raise KmlError {
  match first_element(elem, "MultiGeometry") {
    None => None
    Some(multi) => {
      let geoms : Array[Geometry] = []
      let mut i = 0
      while i < multi.children.length() {
        match multi.children[i] {
          Element(child) =>
            match geometry_from_elem(child) {
              Some(g) => geoms.push(g)
              None => ()
            }
          Text(_) => ()
        }
        i = i + 1
      }
      Some(geoms)
    }
  }
}

///|
/// 解析 KML 颜色 aabbggrr（十六进制）。
fn parse_color(text : String) -> String? {
  let trimmed = trim_text(text)
  let data = @utf8.encode(trimmed)
  if data.length() != 8 {
    return None
  }
  let mut i = 0
  while i < 8 {
    let d = hex_digit(data[i])
    if d < 0 {
      return None
    }
    i = i + 1
  }
  Some(trimmed)
}

///|
/// 解析一个 Style 元素（id + LineStyle/PolyStyle 的颜色与宽度）。
fn parse_style(elem : XmlElement) -> KmlStyle {
  let id = match first_element(elem, "id") {
    Some(_) => "x"
    None => ""
  }
  // 实际 id 是元素属性，不是子元素
  let real_id = match elem.attr("id") {
    Some(v) => v
    None => id
  }
  let mut line_color : String? = None
  let mut line_width : Double? = None
  let mut fill_color : String? = None
  match first_element(elem, "LineStyle") {
    Some(ls) => {
      match first_element(ls, "color") {
        Some(c) => line_color = parse_color(c.text())
        None => ()
      }
      match first_element(ls, "width") {
        Some(w) => line_width = parse_double(trim_text(w.text()))
        None => ()
      }
    }
    None => ()
  }
  match first_element(elem, "PolyStyle") {
    Some(ps) =>
      match first_element(ps, "color") {
        Some(c) => fill_color = parse_color(c.text())
        None => ()
      }
    None => ()
  }
  { id: real_id, line_color, line_width, fill_color, }
}

///|
/// 解析一个 Placemark。
fn parse_placemark(elem : XmlElement) -> Placemark raise KmlError {
  let name = match child_text(elem, "name") {
    Some(t) => t
    None => ""
  }
  let description = match child_text(elem, "description") {
    Some(t) => t
    None => ""
  }
  let geometry : Geometry? = match parse_point(elem) {
    Some(p) => Some(Geometry::Point(p))
    None =>
      match parse_line_string(elem) {
        Some(ls) => Some(Geometry::LineString(ls))
        None =>
          match parse_polygon(elem) {
            Some(poly) => Some(Geometry::Polygon(poly))
            None =>
              match parse_multi_geometry(elem) {
                Some(geoms) => Some(Geometry::MultiGeometry(geoms))
                None => None
              }
          }
      }
  }
  let style_url = match child_text(elem, "styleUrl") {
    Some(t) => t
    None => ""
  }
  { name, description, geometry, style_url, }
}

///|
/// 递归遍历元素树，收集 Document 名称与 Placemark。
fn walk(elem : XmlElement, acc : Collector) -> Unit raise KmlError {
  if elem.name == "Document" && acc.document_name == "" {
    match child_text(elem, "name") {
      Some(t) => acc.document_name = t
      None => ()
    }
  }
  if elem.name == "Placemark" {
    acc.placemarks.push(parse_placemark(elem))
  }
  if elem.name == "Style" {
    acc.styles.push(parse_style(elem))
  }
  let mut i = 0
  while i < elem.children.length() {
    match elem.children[i] {
      Element(child) => walk(child, acc)
      Text(_) => ()
    }
    i = i + 1
  }
}

///|
/// 解析 KML 文本。
pub fn parse(text : String) -> KmlDocument raise KmlError {
  let root = parse_xml(text)
  let acc : Collector = { document_name: "", placemarks: [], styles: [], }
  walk(root, acc)
  { name: acc.document_name, placemarks: acc.placemarks, styles: acc.styles, }
}
