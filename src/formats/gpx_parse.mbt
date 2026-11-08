// GPX 1.1 导入：wpt / rte / trk → KML 文档。
//
// 映射：wpt → Point；rte → LineString；trk 的单段 → LineString，
// 多段 → MultiGeometry(LineString...)。

///|
/// 从 wpt/rtept/trkpt 元素读一个点（lat/lon 属性 + 可选 ele）。
fn point_from_gpx(
  elem : @core.XmlElement,
) -> @core.KmlPoint raise @core.KmlError {
  let lat = match elem.attr("lat") {
    Some(v) => @core.parse_double(@core.trim_text(v))
    None => raise BadGpx("missing lat")
  }
  let lon = match elem.attr("lon") {
    Some(v) => @core.parse_double(@core.trim_text(v))
    None => raise BadGpx("missing lon")
  }
  let alt = match @core.first_element(elem, "ele") {
    Some(e) => @core.parse_double(@core.trim_text(e.text()))
    None => None
  }
  match (lon, lat) {
    (Some(lon), Some(lat)) => { lon, lat, alt, }
    _ => raise BadGpx("lat/lon not numeric")
  }
}

///|
/// 读一组子点（rtept / trkpt）。
fn points_from_gpx(
  elem : @core.XmlElement,
  child_name : String,
) -> Array[@core.KmlPoint] raise @core.KmlError {
  let out : Array[@core.KmlPoint] = []
  let mut i = 0
  while i < elem.children.length() {
    match elem.children[i] {
      Element(child) =>
        if child.name == child_name {
          out.push(point_from_gpx(child))
        }
      Text(_) => ()
    }
    i = i + 1
  }
  out
}

///|
/// 读一个 GPX 名称子元素。
fn name_from_gpx(elem : @core.XmlElement) -> String {
  match @core.first_element(elem, "name") {
    Some(n) => @core.trim_text(n.text())
    None => ""
  }
}

///|
/// 从 GPX 文本导入 KML 文档。
pub fn from_gpx(text : String) -> @core.KmlDocument raise @core.KmlError {
  let root = @core.parse_xml(text)
  let placemarks : Array[@core.Placemark] = []
  if root.name != "gpx" {
    raise BadGpx("root element is not gpx")
  }
  let mut i = 0
  while i < root.children.length() {
    match root.children[i] {
      Element(child) =>
        if child.name == "wpt" {
          placemarks.push({
            name: name_from_gpx(child),
            description: "",
            geometry: Some(@core.Geometry::Point(point_from_gpx(child))),
            style_url: "",
            extended_data: [],
            folder: "",
            timestamp: None,
          })
        } else if child.name == "rte" {
          let pts = points_from_gpx(child, "rtept")
          if pts.length() > 0 {
            placemarks.push({
              name: name_from_gpx(child),
              description: "",
              geometry: Some(@core.Geometry::LineString({ points: pts, })),
              style_url: "",
              extended_data: [],
              folder: "",
              timestamp: None,
            })
          }
        } else if child.name == "trk" {
          let segs : Array[Array[@core.KmlPoint]] = []
          let mut k = 0
          while k < child.children.length() {
            match child.children[k] {
              Element(seg) =>
                if seg.name == "trkseg" {
                  let pts = points_from_gpx(seg, "trkpt")
                  if pts.length() > 0 {
                    segs.push(pts)
                  }
                }
              Text(_) => ()
            }
            k = k + 1
          }
          if segs.length() == 1 {
            placemarks.push({
              name: name_from_gpx(child),
              description: "",
              geometry: Some(@core.Geometry::LineString({ points: segs[0], })),
              style_url: "",
              extended_data: [],
              folder: "",
              timestamp: None,
            })
          } else if segs.length() > 1 {
            let parts : Array[@core.Geometry] = []
            let mut s = 0
            while s < segs.length() {
              parts.push(@core.Geometry::LineString({ points: segs[s], }))
              s = s + 1
            }
            placemarks.push({
              name: name_from_gpx(child),
              description: "",
              geometry: Some(@core.Geometry::MultiGeometry(parts)),
              style_url: "",
              extended_data: [],
              folder: "",
              timestamp: None,
            })
          }
        }
      Text(_) => ()
    }
    i = i + 1
  }
  { name: "", placemarks, styles: [], style_maps: [], }
}
