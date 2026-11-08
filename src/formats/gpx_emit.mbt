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
      @core.push_lit(out, "&amp;")
    } else if b == b'<' {
      @core.push_lit(out, "&lt;")
    } else if b == b'>' {
      @core.push_lit(out, "&gt;")
    } else {
      out.push(b)
    }
    i = i + 1
  }
}

///|
/// 追加一个坐标对。
fn push_trkpt(out : Array[Byte], p : @core.KmlPoint) -> Unit {
  @core.push_lit(out, "<trkpt lat=\"")
  @core.push_lit(out, p.lat.to_string())
  @core.push_lit(out, "\" lon=\"")
  @core.push_lit(out, p.lon.to_string())
  @core.push_lit(out, "\">")
  match p.alt {
    Some(a) => {
      @core.push_lit(out, "<ele>")
      @core.push_lit(out, a.to_string())
      @core.push_lit(out, "</ele>")
    }
    None => ()
  }
  @core.push_lit(out, "</trkpt>")
}

///|
/// 追加一个 track。
fn push_trkseg(out : Array[Byte], points : Array[@core.KmlPoint]) -> Unit {
  @core.push_lit(out, "<trk><trkseg>")
  let mut i = 0
  while i < points.length() {
    push_trkpt(out, points[i])
    i = i + 1
  }
  @core.push_lit(out, "</trkseg></trk>")
}

///|
/// 把 KML 文档导出为 GPX 1.1。
pub fn to_gpx(doc : @core.KmlDocument) -> String {
  let out : Array[Byte] = []
  @core.push_lit(out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  @core.push_newline(out)
  @core.push_lit(
    out, "<gpx version=\"1.1\" creator=\"moonkml\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
  )
  @core.push_newline(out)
  if doc.name != "" {
    @core.push_lit(out, "<metadata><name>")
    push_xml_escaped(out, doc.name)
    @core.push_lit(out, "</name></metadata>")
    @core.push_newline(out)
  }
  let mut i = 0
  while i < doc.placemarks.length() {
    let pm = doc.placemarks[i]
    match pm.geometry {
      Some(@core.Geometry::Point(p)) => {
        @core.push_lit(out, "<wpt lat=\"")
        @core.push_lit(out, p.lat.to_string())
        @core.push_lit(out, "\" lon=\"")
        @core.push_lit(out, p.lon.to_string())
        @core.push_lit(out, "\"><name>")
        push_xml_escaped(out, pm.name)
        @core.push_lit(out, "</name></wpt>")
      }
      Some(@core.Geometry::LineString(ls)) => push_trkseg(out, ls.points)
      Some(@core.Geometry::GxTrack(track)) => push_trkseg(out, track.coords)
      _ => ()
    }
    @core.push_newline(out)
    i = i + 1
  }
  @core.push_lit(out, "</gpx>")
  @utf8.decode_lossy(Bytes::from_array(out))
}
