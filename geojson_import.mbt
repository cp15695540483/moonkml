// GeoJSON 导入：RFC 7946 FeatureCollection → KML 文档。
//
// 支持的几何：Point / LineString / Polygon / MultiPoint / MultiLineString /
// MultiPolygon；Multi* 映射为 KML 的 MultiGeometry。

///|
/// 取 Json 对象。
fn json_as_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(m) => Some(m)
    _ => None
  }
}

///|
/// 取 Json 数组。
fn json_as_array(value : Json) -> Array[Json]? {
  match value {
    Json::Array(a) => Some(a)
    _ => None
  }
}

///|
/// 取 Json 字符串。
fn json_as_string(value : Json) -> String? {
  match value {
    Json::String(s) => Some(s)
    _ => None
  }
}

///|
/// 取 Json 数字。
fn json_as_number(value : Json) -> Double? {
  match value {
    Json::Number(n, ..) => Some(n)
    _ => None
  }
}

///|
/// 从 Json 对象里取字段。
fn json_field(obj : Map[String, Json], key : String) -> Json? {
  obj.get(key)
}

///|
/// 解析一个 GeoJSON position（[lon, lat] 或 [lon, lat, alt]）。
fn position_from_json(value : Json) -> KmlPoint raise KmlError {
  match json_as_array(value) {
    None => raise BadGeoJson("position is not an array")
    Some(arr) => {
      if arr.length() < 2 {
        raise BadGeoJson("position needs at least 2 numbers")
      }
      let lon = json_as_number(arr[0])
      let lat = json_as_number(arr[1])
      let alt = if arr.length() >= 3 { json_as_number(arr[2]) } else { None }
      match (lon, lat) {
        (Some(lon), Some(lat)) => { lon, lat, alt, }
        _ => raise BadGeoJson("position is not numeric")
      }
    }
  }
}

///|
/// 解析一串 position。
fn positions_from_json(value : Json) -> Array[KmlPoint] raise KmlError {
  match json_as_array(value) {
    None => raise BadGeoJson("coordinates is not an array")
    Some(arr) => {
      let out : Array[KmlPoint] = []
      let mut i = 0
      while i < arr.length() {
        out.push(position_from_json(arr[i]))
        i = i + 1
      }
      out
    }
  }
}

///|
/// 解析 GeoJSON 几何成 KML 几何。
fn geometry_from_json(value : Json) -> Geometry? raise KmlError {
  match json_as_object(value) {
    None => raise BadGeoJson("geometry is not an object")
    Some(obj) => {
      let kind = match json_field(obj, "type") {
        Some(t) =>
          match json_as_string(t) {
            Some(s) => s
            None => raise BadGeoJson("geometry type is not a string")
          }
        None => raise BadGeoJson("geometry has no type")
      }
      let coords = match json_field(obj, "coordinates") {
        Some(c) => c
        None => raise BadGeoJson("geometry has no coordinates")
      }
      if kind == "Point" {
        Some(Geometry::Point(position_from_json(coords)))
      } else if kind == "LineString" {
        Some(Geometry::LineString({ points: positions_from_json(coords), }))
      } else if kind == "Polygon" {
        Some(Geometry::Polygon(polygon_from_json(coords)))
      } else if kind == "MultiPoint" {
        let pts = positions_from_json(coords)
        let parts : Array[Geometry] = []
        let mut i = 0
        while i < pts.length() {
          parts.push(Geometry::Point(pts[i]))
          i = i + 1
        }
        Some(Geometry::MultiGeometry(parts))
      } else if kind == "MultiLineString" {
        let lines = json_as_array(coords)
        match lines {
          None => raise BadGeoJson("MultiLineString coordinates invalid")
          Some(ls) => {
            let parts : Array[Geometry] = []
            let mut i = 0
            while i < ls.length() {
              parts.push(
                Geometry::LineString({ points: positions_from_json(ls[i]), }),
              )
              i = i + 1
            }
            Some(Geometry::MultiGeometry(parts))
          }
        }
      } else if kind == "MultiPolygon" {
        let polys = json_as_array(coords)
        match polys {
          None => raise BadGeoJson("MultiPolygon coordinates invalid")
          Some(ps) => {
            let parts : Array[Geometry] = []
            let mut i = 0
            while i < ps.length() {
              parts.push(Geometry::Polygon(polygon_from_json(ps[i])))
              i = i + 1
            }
            Some(Geometry::MultiGeometry(parts))
          }
        }
      } else {
        None
      }
    }
  }
}

///|
/// 解析 GeoJSON Polygon 的 coordinates：第一个环是外环，其余是内环。
fn polygon_from_json(value : Json) -> KmlPolygon raise KmlError {
  match json_as_array(value) {
    None => raise BadGeoJson("Polygon coordinates is not an array")
    Some(rings) => {
      if rings.length() == 0 {
        raise BadGeoJson("Polygon needs at least one ring")
      }
      let outer : LinearRing = { points: positions_from_json(rings[0]), }
      let inner : Array[LinearRing] = []
      let mut i = 1
      while i < rings.length() {
        inner.push({ points: positions_from_json(rings[i]), })
        i = i + 1
      }
      { outer, inner, }
    }
  }
}

///|
/// 解析一个 Feature。
fn placemark_from_feature(value : Json) -> Placemark raise KmlError {
  match json_as_object(value) {
    None => raise BadGeoJson("feature is not an object")
    Some(obj) => {
      let mut name = ""
      let mut description = ""
      match json_field(obj, "properties") {
        Some(props) =>
          match json_as_object(props) {
            Some(p) => {
              match json_field(p, "name") {
                Some(n) =>
                  match json_as_string(n) {
                    Some(s) => name = s
                    None => ()
                  }
                None => ()
              }
              match json_field(p, "description") {
                Some(d) =>
                  match json_as_string(d) {
                    Some(s) => description = s
                    None => ()
                  }
                None => ()
              }
            }
            None => ()
          }
        None => ()
      }
      let geometry = match json_field(obj, "geometry") {
        Some(g) => geometry_from_json(g)
        None => None
      }
      {
        name,
        description,
        geometry,
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      }
    }
  }
}

///|
/// 从 GeoJSON 文本导入 KML 文档。
pub fn from_geojson(text : String) -> KmlDocument raise KmlError {
  let json = @json.parse(text) catch { _ => raise BadGeoJson("invalid JSON") }
  let obj = match json_as_object(json) {
    Some(o) => o
    None => raise BadGeoJson("root is not an object")
  }
  let kind = match json_field(obj, "type") {
    Some(t) =>
      match json_as_string(t) {
        Some(s) => s
        None => raise BadGeoJson("type is not a string")
      }
    None => raise BadGeoJson("root has no type")
  }
  let placemarks : Array[Placemark] = []
  if kind == "FeatureCollection" {
    match json_field(obj, "features") {
      Some(f) =>
        match json_as_array(f) {
          Some(features) => {
            let mut i = 0
            while i < features.length() {
              placemarks.push(placemark_from_feature(features[i]))
              i = i + 1
            }
          }
          None => raise BadGeoJson("features is not an array")
        }
      None => raise BadGeoJson("FeatureCollection has no features")
    }
  } else if kind == "Feature" {
    placemarks.push(placemark_from_feature(json))
  } else {
    let geometry = geometry_from_json(json)
    placemarks.push({
      name: "",
      description: "",
      geometry,
      style_url: "",
      extended_data: [],
      folder: "",
      timestamp: None,
    })
  }
  { name: "", placemarks, styles: [], style_maps: [], }
}
