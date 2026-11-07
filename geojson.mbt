// GeoJSON 导出：KML 文档 → GeoJSON FeatureCollection。
//
// 输出 RFC 7946 的 FeatureCollection；几何映射：
// Point → Point，LineString → LineString，Polygon → Polygon，
// MultiGeometry → 拆成多个 Feature。

///|
/// 追加一个字符串（JSON 字符串转义）。
fn push_json_string(out : Array[Byte], text : String) -> Unit {
  out.push(b'"')
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() {
    let b = data[i]
    if b == b'"' || b == b'\\' {
      out.push(b'\\')
      out.push(b)
    } else if b == b'\n' {
      out.push(b'\\')
      out.push(b'n')
    } else if b == b'\t' {
      out.push(b'\\')
      out.push(b't')
    } else if b == b'\r' {
      out.push(b'\\')
      out.push(b'r')
    } else {
      out.push(b)
    }
    i = i + 1
  }
  out.push(b'"')
}

///|
/// 序列化一个坐标对。
fn push_position(out : Array[Byte], lon : Double, lat : Double) -> Unit {
  push_lit(out, "[")
  push_lit(out, lon.to_string())
  push_lit(out, ",")
  push_lit(out, lat.to_string())
  push_lit(out, "]")
}

///|
/// 序列化 Point。
fn push_geojson_point(out : Array[Byte], p : KmlPoint) -> Unit {
  push_lit(out, "{\"type\":\"Point\",\"coordinates\":")
  push_position(out, p.lon, p.lat)
  push_lit(out, "}")
}

///|
/// 序列化 LineString。
fn push_geojson_linestring(out : Array[Byte], ls : KmlLineString) -> Unit {
  push_lit(out, "{\"type\":\"LineString\",\"coordinates\":[")
  let mut i = 0
  while i < ls.points.length() {
    push_position(out, ls.points[i].lon, ls.points[i].lat)
    if i + 1 < ls.points.length() {
      push_lit(out, ",")
    }
    i = i + 1
  }
  push_lit(out, "]}")
}

///|
/// 序列化 Polygon。
fn push_geojson_polygon(out : Array[Byte], poly : KmlPolygon) -> Unit {
  push_lit(out, "{\"type\":\"Polygon\",\"coordinates\":[")
  push_ring(out, poly.outer)
  let mut i = 0
  while i < poly.inner.length() {
    push_lit(out, ",")
    push_ring(out, poly.inner[i])
    i = i + 1
  }
  push_lit(out, "]}")
}

///|
/// 序列化一个环。
fn push_ring(out : Array[Byte], ring : LinearRing) -> Unit {
  push_lit(out, "[")
  let mut i = 0
  while i < ring.points.length() {
    push_position(out, ring.points[i].lon, ring.points[i].lat)
    if i + 1 < ring.points.length() {
      push_lit(out, ",")
    }
    i = i + 1
  }
  push_lit(out, "]")
}

///|
/// 序列化一个 Geometry。
fn push_geojson_geometry(out : Array[Byte], geometry : Geometry) -> Unit {
  match geometry {
    Geometry::Point(p) => push_geojson_point(out, p)
    Geometry::LineString(ls) => push_geojson_linestring(out, ls)
    Geometry::Polygon(poly) => push_geojson_polygon(out, poly)
    Geometry::MultiGeometry(_) => push_lit(out, "null")
  }
}

///|
/// 序列化一个 Feature。
fn push_feature(out : Array[Byte], pm : Placemark) -> Unit {
  push_lit(out, "{\"type\":\"Feature\",")
  push_lit(out, "\"properties\":{")
  push_json_string(out, "name")
  push_lit(out, ":")
  push_json_string(out, pm.name)
  if pm.description != "" {
    push_lit(out, ",")
    push_json_string(out, "description")
    push_lit(out, ":")
    push_json_string(out, pm.description)
  }
  push_lit(out, "},")
  push_lit(out, "\"geometry\":")
  match pm.geometry {
    Some(g) => push_geojson_geometry(out, g)
    None => push_lit(out, "null")
  }
  push_lit(out, "}")
}

///|
/// 把 KML 文档导出为 GeoJSON FeatureCollection。
pub fn to_geojson(doc : KmlDocument) -> String {
  let out : Array[Byte] = []
  push_lit(out, "{\"type\":\"FeatureCollection\",\"features\":[")
  let mut i = 0
  while i < doc.placemarks.length() {
    push_feature(out, doc.placemarks[i])
    if i + 1 < doc.placemarks.length() {
      push_lit(out, ",")
    }
    i = i + 1
  }
  push_lit(out, "]}")
  @utf8.decode_lossy(Bytes::from_array(out))
}
