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
/// 一条 gx:Track：Google Earth 扩展的 GPS 轨迹，坐标与时间戳一一对应。
pub(all) struct KmlGxTrack {
  /// 每个点的时间戳字符串（<when>），可为空
  whens : Array[String]
  /// 轨迹点（lon/lat/alt，空格分隔的 <gx:coord>）
  coords : Array[KmlPoint]
}

///|
/// 几何类型。
pub(all) enum Geometry {
  Point(KmlPoint)
  LineString(KmlLineString)
  Polygon(KmlPolygon)
  MultiGeometry(Array[Geometry])
  GxTrack(KmlGxTrack)
}

///|
/// 样式表：id → 样式定义。
pub(all) struct KmlDocument {
  name : String
  placemarks : Array[Placemark]
  styles : Array[KmlStyle]
  style_maps : Array[KmlStyleMap]
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
/// 一个 StyleMap：normal / highlight 两个键指向的样式 id。
pub(all) struct KmlStyleMap {
  id : String
  normal : String
  highlight : String
}

///|
/// 一个扩展数据条目（<Data name=".."><value>..</value></Data>）。
pub(all) struct KmlData {
  name : String
  value : String
}

///|
/// 时间信息：TimeStamp（瞬时）或 TimeSpan（区间），三者至多一个非空。
pub(all) struct KmlTime {
  when : String
  begin : String
  end : String
}

///|
/// 一个 Placemark。
pub(all) struct Placemark {
  name : String
  description : String
  geometry : Geometry?
  style_url : String
  extended_data : Array[KmlData]
  /// 所属 Folder 路径（"A/B"），顶层为空串
  folder : String
  /// 时间信息
  timestamp : KmlTime?
}

///|
/// 便捷构造：只给名称与几何，其余字段取默认值。
pub fn Placemark::new(name : String, geometry : Geometry?) -> Placemark {
  {
    name,
    description: "",
    geometry,
    style_url: "",
    extended_data: [],
    folder: "",
    timestamp: None,
  }
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
/// gx:Track 的点数。
pub fn KmlGxTrack::point_count(self : KmlGxTrack) -> Int32 {
  self.coords.length()
}

///|
/// 是否为 gx:Track。
pub fn Placemark::has_gx_track(self : Placemark) -> Bool {
  match self.geometry {
    Some(Geometry::GxTrack(_)) => true
    _ => false
  }
}

///|
/// 多边形的内环数。
pub fn KmlPolygon::inner_count(self : KmlPolygon) -> Int32 {
  self.inner.length()
}

///|
/// 是否有时间信息。
pub fn Placemark::has_time(self : Placemark) -> Bool {
  self.timestamp is Some(_)
}

///|
/// Placemark 的扩展数据条目数。
pub fn Placemark::data_count(self : Placemark) -> Int32 {
  self.extended_data.length()
}

///|
/// 按名字找扩展数据值。
pub fn Placemark::find_data(self : Placemark, name : String) -> String? {
  let mut i = 0
  while i < self.extended_data.length() {
    if self.extended_data[i].name == name {
      return Some(self.extended_data[i].value)
    }
    i = i + 1
  }
  None
}

///|
/// 样式数量。
pub fn KmlDocument::style_count(self : KmlDocument) -> Int32 {
  self.styles.length()
}

///|
/// StyleMap 数量。
pub fn KmlDocument::style_map_count(self : KmlDocument) -> Int32 {
  self.style_maps.length()
}

///|
/// 按 id 找 StyleMap。
pub fn KmlDocument::find_style_map(
  self : KmlDocument,
  id : String,
) -> KmlStyleMap? {
  let mut i = 0
  while i < self.style_maps.length() {
    if self.style_maps[i].id == id {
      return Some(self.style_maps[i])
    }
    i = i + 1
  }
  None
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
