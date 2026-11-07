// KML 文档模型。
//
// 几何统一用 Geometry 枚举承载（Point / LineString / Polygon），
// 一个 Placemark 至多一个几何；样式与扩展数据后续增量加入。

///|
/// 一个 WGS-84 坐标点。`alt` 缺省表示 KML 未给出高度。
pub(all) struct KmlPoint {
  lon : Double
  lat : Double
  alt : Double?
}

///|
/// 一条折线：有序的点列。
pub(all) struct KmlLineString {
  points : Array[KmlPoint]
}

///|
/// 一个闭合环；KML 要求首尾点相同。
pub(all) struct LinearRing {
  points : Array[KmlPoint]
}

///|
/// 一个多边形：外环 + 零或多个内环（洞）。
pub(all) struct KmlPolygon {
  outer : LinearRing
  inner : Array[LinearRing]
}

///|
/// 几何类型。
pub(all) enum Geometry {
  Point(KmlPoint)
  LineString(KmlLineString)
  Polygon(KmlPolygon)
  MultiGeometry(Array[Geometry])
}

///|
/// 一个 Placemark。
pub(all) struct Placemark {
  name : String
  description : String
  geometry : Geometry?
  style_url : String
}

///|
/// 样式表：id → 样式定义。
pub(all) struct KmlDocument {
  name : String
  placemarks : Array[Placemark]
  styles : Array[KmlStyle]
}

///|
/// 一个样式定义：线条颜色与宽度、填充颜色。
pub(all) struct KmlStyle {
  id : String
  line_color : String?
  line_width : Double?
  fill_color : String?
}

///|
/// Placemark 数量。
pub fn KmlDocument::placemark_count(self : KmlDocument) -> Int32 {
  self.placemarks.length()
}

///|
/// 是否有几何。
pub fn Placemark::has_geometry(self : Placemark) -> Bool {
  self.geometry is Some(_)
}

///|
/// 是否有点几何。
pub fn Placemark::has_point(self : Placemark) -> Bool {
  match self.geometry {
    Some(Geometry::Point(_)) => true
    _ => false
  }
}

///|
/// 是否为多重几何。
pub fn Placemark::has_multi_geometry(self : Placemark) -> Bool {
  match self.geometry {
    Some(Geometry::MultiGeometry(_)) => true
    _ => false
  }
}

///|
/// 是否有折线几何。
pub fn Placemark::has_line_string(self : Placemark) -> Bool {
  match self.geometry {
    Some(Geometry::LineString(_)) => true
    _ => false
  }
}

///|
/// 折线的顶点数。
pub fn KmlLineString::point_count(self : KmlLineString) -> Int32 {
  self.points.length()
}

///|
/// 环的顶点数。
pub fn LinearRing::point_count(self : LinearRing) -> Int32 {
  self.points.length()
}

///|
/// 多边形的内环数。
pub fn KmlPolygon::inner_count(self : KmlPolygon) -> Int32 {
  self.inner.length()
}

///|
/// 样式数量。
pub fn KmlDocument::style_count(self : KmlDocument) -> Int32 {
  self.styles.length()
}

///|
/// 按 id 找样式。
pub fn KmlDocument::find_style(self : KmlDocument, id : String) -> KmlStyle? {
  let mut i = 0
  while i < self.styles.length() {
    if self.styles[i].id == id {
      return Some(self.styles[i])
    }
    i = i + 1
  }
  None
}
