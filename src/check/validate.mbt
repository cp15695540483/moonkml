// 文档校验：收集结构性/取值范围问题，不抛错。
//
// 面向真实数据的质检：坐标越界、环未闭合、顶点不足、样式引用悬空、
// gx:Track 时间戳与坐标数量不一致等。

///|
/// 一条校验问题：出问题的 Placemark 标识 + 说明。
pub(all) struct ValidationIssue {
  placemark : String
  message : String
}

///|
/// 坐标是否在合法范围内。
fn valid_position(p : @core.KmlPoint) -> Bool {
  !p.lon.is_nan() &&
  !p.lat.is_nan() &&
  !p.lon.is_inf() &&
  !p.lat.is_inf() &&
  p.lon >= -180.0 &&
  p.lon <= 180.0 &&
  p.lat >= -90.0 &&
  p.lat <= 90.0
}

///|
/// 两个点是否相同（按 1e-9 容差）。
fn same_point(a : @core.KmlPoint, b : @core.KmlPoint) -> Bool {
  (a.lon - b.lon).abs() <= 1.0e-9 && (a.lat - b.lat).abs() <= 1.0e-9
}

///|
/// 校验一个点列，把问题追加进 out。
fn validate_points(
  label : String,
  kind : String,
  points : Array[@core.KmlPoint],
  min_count : Int32,
  out : Array[ValidationIssue],
) -> Unit {
  if points.length() < min_count {
    out.push({
      placemark: label,
      message: kind +
      " 顶点不足：需要 " +
      min_count.to_string() +
      " 个，实际 " +
      points.length().to_string(),
    })
  }
  let mut i = 0
  while i < points.length() {
    if !valid_position(points[i]) {
      out.push({
        placemark: label,
        message: kind +
        " 第 " +
        i.to_string() +
        " 个坐标越界或非有限值",
      })
    }
    i = i + 1
  }
}

///|
/// 校验一个环。
fn validate_ring(
  label : String,
  kind : String,
  ring : @core.LinearRing,
  out : Array[ValidationIssue],
) -> Unit {
  validate_points(label, kind, ring.points, 4, out)
  if ring.points.length() >= 2 {
    let first = ring.points[0]
    let last = ring.points[ring.points.length() - 1]
    if !same_point(first, last) {
      out.push({ placemark: label, message: kind + " 首尾点不闭合", })
    }
  }
}

///|
/// 校验一个几何。
fn validate_geometry(
  label : String,
  geometry : @core.Geometry,
  out : Array[ValidationIssue],
) -> Unit {
  match geometry {
    @core.Geometry::Point(p) =>
      if !valid_position(p) {
        out.push({
          placemark: label,
          message: "Point 坐标越界或非有限值",
        })
      }
    @core.Geometry::LineString(ls) =>
      validate_points(label, "LineString", ls.points, 2, out)
    @core.Geometry::Polygon(poly) => {
      validate_ring(label, "Polygon 外环", poly.outer, out)
      let mut i = 0
      while i < poly.inner.length() {
        validate_ring(
          label,
          "Polygon 内环 " + i.to_string(),
          poly.inner[i],
          out,
        )
        i = i + 1
      }
    }
    @core.Geometry::MultiGeometry(parts) => {
      let mut i = 0
      while i < parts.length() {
        validate_geometry(label, parts[i], out)
        i = i + 1
      }
    }
    @core.Geometry::GxTrack(track) => {
      validate_points(label, "gx:Track", track.coords, 1, out)
      if track.whens.length() > 0 &&
        track.whens.length() != track.coords.length() {
        out.push({
          placemark: label,
          message: "gx:Track 时间戳数 " +
          track.whens.length().to_string() +
          " 与坐标数 " +
          track.coords.length().to_string() +
          " 不一致",
        })
      }
    }
  }
}

///|
/// 校验整个文档，返回全部问题（空数组表示通过）。
pub fn validate(doc : @core.KmlDocument) -> Array[ValidationIssue] {
  let out : Array[ValidationIssue] = []
  let mut i = 0
  while i < doc.placemarks.length() {
    let pm = doc.placemarks[i]
    let label = if pm.name != "" {
      pm.name
    } else {
      "placemark[" + i.to_string() + "]"
    }
    match pm.geometry {
      Some(g) => validate_geometry(label, g, out)
      None => out.push({ placemark: label, message: "没有几何", })
    }
    if pm.style_url != "" && pm.style_url.has_prefix("#") {
      let id = strip_hash(pm.style_url)
      if doc.find_style(id) is None && doc.find_style_map(id) is None {
        out.push({
          placemark: label,
          message: "样式引用悬空：" + pm.style_url,
        })
      }
    }
    i = i + 1
  }
  out
}

///|
/// 去掉 styleUrl 的前导 #。
fn strip_hash(url : String) -> String {
  let data = @utf8.encode(url)
  if data.length() > 0 && data[0] == b'#' {
    @utf8.decode_lossy(data.clamped_view(start=1, end=data.length()))
  } else {
    url
  }
}
