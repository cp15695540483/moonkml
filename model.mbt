// KML 文档模型：只保留「解析 → 使用」需要的最小结构。
//
// 目前覆盖 Point；线/面/样式在后续增量里加入，模型字段保持向后兼容。

///|
/// 一个 WGS-84 坐标点。`alt` 缺省表示 KML 未给出高度。
pub(all) struct KmlPoint {
  lon : Double
  lat : Double
  alt : Double?
}

///|
/// 一个 Placemark：名称、描述与可选的几何。
pub(all) struct Placemark {
  name : String
  description : String
  point : KmlPoint?
}

///|
/// 解析后的 KML 文档。
pub(all) struct KmlDocument {
  name : String
  placemarks : Array[Placemark]
}

///|
/// Placemark 数量。
pub fn KmlDocument::placemark_count(self : KmlDocument) -> Int32 {
  self.placemarks.length()
}

///|
/// 是否有点几何。
pub fn Placemark::has_point(self : Placemark) -> Bool {
  self.point is Some(_)
}
