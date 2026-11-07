// GPX 导出：KML 文档 → GPX 1.1。
//
// 点、线都映射为 trkpt/rtept；面不做映射（GPX 无面）。

///|
/// 追加一个字符串（XML 转义）。
fn push_xml_escaped(out : Array[Byte], text : String) -> Unit {
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
    } else {
      out.push(b)
    }
    i = i + 1
  }
}

///|
/// 追加一个坐标对。
fn push_trkpt(out : Array[Byte], p : KmlPoint) -> Unit {
  push_lit(out, "<trkpt lat=\"")
  push_lit(out, p.lat.to_string())
  push_lit(out, "\" lon=\"")
  push_lit(out, p.lon.to_string())
  push_lit(out, "\">")
  match p.alt {
    Some(a) => {
      push_lit(out, "<ele>")
      push_lit(out, a.to_string())
      push_lit(out, "</ele>")
    }
    None => ()
  }
  push_lit(out, "</trkpt>")
}

///|
/// 追加一个 track。
fn push_trkseg(out : Array[Byte], ls : KmlLineString) -> Unit {
  push_lit(out, "<trk><trkseg>")
  let mut i = 0
  while i < ls.points.length() {
    push_trkpt(out, ls.points[i])
    i = i + 1
  }
  push_lit(out, "</trkseg></trk>")
}

///|
/// 把 KML 文档导出为 GPX 1.1。
pub fn to_gpx(doc : KmlDocument) -> String {
  let out : Array[Byte] = []
  push_lit(out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  push_newline(out)
  push_lit(
    out, "<gpx version=\"1.1\" creator=\"moonkml\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
  )
  push_newline(out)
  if doc.name != "" {
    push_lit(out, "<metadata><name>")
    push_xml_escaped(out, doc.name)
    push_lit(out, "</name></metadata>")
    push_newline(out)
  }
  let mut i = 0
  while i < doc.placemarks.length() {
    let pm = doc.placemarks[i]
    match pm.geometry {
      Some(Geometry::Point(p)) => {
        push_lit(out, "<wpt lat=\"")
        push_lit(out, p.lat.to_string())
        push_lit(out, "\" lon=\"")
        push_lit(out, p.lon.to_string())
        push_lit(out, "\"><name>")
        push_xml_escaped(out, pm.name)
        push_lit(out, "</name></wpt>")
      }
      Some(Geometry::LineString(ls)) => push_trkseg(out, ls)
      _ => ()
    }
    push_newline(out)
    i = i + 1
  }
  push_lit(out, "</gpx>")
  @utf8.decode_lossy(Bytes::from_array(out))
}
