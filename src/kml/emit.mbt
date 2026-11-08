// KML 序列化：模型到 KML 文本，坐标用最短可往返表示。

// KML 序列化：把文档模型转回 KML 文本。
//
// 输出带 XML 声明、kml 根与命名空间、Document；文本做 XML 转义。
// 这是读写闭环的一半，round-trip 测试会用它配合 parse。

///|
/// 追加一段文本的 XML 转义结果到字节数组。

///|
/// 追加字面量字符串的 UTF-8 字节。

///|
/// 追加换行。

///|
/// 序列化一个坐标点。
fn push_point_coords(out : Array[Byte], p : @core.KmlPoint) -> Unit {
  @core.push_double(out, p.lon)
  out.push(b',')
  @core.push_double(out, p.lat)
  match p.alt {
    Some(a) => {
      out.push(b',')
      @core.push_double(out, a)
    }
    None => ()
  }
}

///|
/// 追加双精度浮点：用最短可往返的 to_string。

///|
/// 序列化一个点列（LineString 或 LinearRing 共用）。
fn push_points(out : Array[Byte], points : Array[@core.KmlPoint]) -> Unit {
  let mut i = 0
  while i < points.length() {
    push_point_coords(out, points[i])
    if i + 1 < points.length() {
      @core.push_lit(out, " ")
    }
    i = i + 1
  }
}

///|
/// 序列化 Point。
fn serialize_point(out : Array[Byte], p : @core.KmlPoint) -> Unit {
  @core.push_lit(out, "<Point><coordinates>")
  push_point_coords(out, p)
  @core.push_lit(out, "</coordinates></Point>")
}

///|
/// 序列化 LineString。
fn serialize_line_string(out : Array[Byte], ls : @core.KmlLineString) -> Unit {
  @core.push_lit(out, "<LineString><coordinates>")
  push_points(out, ls.points)
  @core.push_lit(out, "</coordinates></LineString>")
}

///|
/// 序列化 LinearRing。
fn serialize_ring(out : Array[Byte], ring : @core.LinearRing) -> Unit {
  @core.push_lit(out, "<LinearRing><coordinates>")
  push_points(out, ring.points)
  @core.push_lit(out, "</coordinates></LinearRing>")
}

///|
/// 序列化 Polygon。
fn serialize_polygon(out : Array[Byte], poly : @core.KmlPolygon) -> Unit {
  @core.push_lit(out, "<Polygon><outerBoundaryIs>")
  serialize_ring(out, poly.outer)
  @core.push_lit(out, "</outerBoundaryIs>")
  let mut i = 0
  while i < poly.inner.length() {
    @core.push_lit(out, "<innerBoundaryIs>")
    serialize_ring(out, poly.inner[i])
    @core.push_lit(out, "</innerBoundaryIs>")
    i = i + 1
  }
  @core.push_lit(out, "</Polygon>")
}

///|
/// 序列化一个 Geometry。
fn serialize_geometry(out : Array[Byte], geometry : @core.Geometry) -> Unit {
  match geometry {
    @core.Geometry::Point(p) => serialize_point(out, p)
    @core.Geometry::LineString(ls) => serialize_line_string(out, ls)
    @core.Geometry::Polygon(poly) => serialize_polygon(out, poly)
    @core.Geometry::MultiGeometry(geoms) => {
      @core.push_lit(out, "<MultiGeometry>")
      let mut i = 0
      while i < geoms.length() {
        serialize_geometry(out, geoms[i])
        i = i + 1
      }
      @core.push_lit(out, "</MultiGeometry>")
    }
    @core.Geometry::GxTrack(track) => {
      @core.push_lit(out, "<gx:Track>")
      let mut i = 0
      while i < track.whens.length() {
        @core.push_lit(out, "<when>")
        @core.push_escaped(out, track.whens[i])
        @core.push_lit(out, "</when>")
        i = i + 1
      }
      let mut k = 0
      while k < track.coords.length() {
        let p = track.coords[k]
        @core.push_lit(out, "<gx:coord>")
        @core.push_double(out, p.lon)
        @core.push_lit(out, " ")
        @core.push_double(out, p.lat)
        @core.push_lit(out, " ")
        match p.alt {
          Some(a) => @core.push_double(out, a)
          None => @core.push_lit(out, "0")
        }
        @core.push_lit(out, "</gx:coord>")
        k = k + 1
      }
      @core.push_lit(out, "</gx:Track>")
    }
  }
}

///|
/// 序列化一个 Placemark。
fn serialize_placemark(out : Array[Byte], pm : @core.Placemark) -> Unit {
  @core.push_lit(out, "<Placemark>")
  if pm.name != "" {
    @core.push_lit(out, "<name>")
    @core.push_escaped(out, pm.name)
    @core.push_lit(out, "</name>")
  }
  if pm.description != "" {
    @core.push_lit(out, "<description>")
    @core.push_escaped(out, pm.description)
    @core.push_lit(out, "</description>")
  }
  if pm.style_url != "" {
    @core.push_lit(out, "<styleUrl>")
    @core.push_escaped(out, pm.style_url)
    @core.push_lit(out, "</styleUrl>")
  }
  match pm.timestamp {
    Some(t) =>
      if t.when != "" {
        @core.push_lit(out, "<TimeStamp><when>")
        @core.push_escaped(out, t.when)
        @core.push_lit(out, "</when></TimeStamp>")
      } else {
        @core.push_lit(out, "<TimeSpan>")
        if t.begin != "" {
          @core.push_lit(out, "<begin>")
          @core.push_escaped(out, t.begin)
          @core.push_lit(out, "</begin>")
        }
        if t.end != "" {
          @core.push_lit(out, "<end>")
          @core.push_escaped(out, t.end)
          @core.push_lit(out, "</end>")
        }
        @core.push_lit(out, "</TimeSpan>")
      }
    None => ()
  }
  if pm.extended_data.length() > 0 {
    @core.push_lit(out, "<ExtendedData>")
    let mut k = 0
    while k < pm.extended_data.length() {
      let d = pm.extended_data[k]
      @core.push_lit(out, "<Data name=\"")
      @core.push_escaped(out, d.name)
      @core.push_lit(out, "\"><value>")
      @core.push_escaped(out, d.value)
      @core.push_lit(out, "</value></Data>")
      k = k + 1
    }
    @core.push_lit(out, "</ExtendedData>")
  }
  match pm.geometry {
    Some(g) => serialize_geometry(out, g)
    None => ()
  }
  @core.push_lit(out, "</Placemark>")
}

///|
/// 把 KML 文档序列化成文本。
pub fn serialize(doc : @core.KmlDocument) -> String {
  let out : Array[Byte] = []
  @core.push_lit(out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  @core.push_newline(out)
  @core.push_lit(out, "<kml xmlns=\"http://www.opengis.net/kml/2.2\">")
  @core.push_newline(out)
  @core.push_lit(out, "<Document>")
  if doc.name != "" {
    @core.push_newline(out)
    @core.push_lit(out, "<name>")
    @core.push_escaped(out, doc.name)
    @core.push_lit(out, "</name>")
  }
  let mut i = 0
  while i < doc.styles.length() {
    @core.push_newline(out)
    let st = doc.styles[i]
    @core.push_lit(out, "<Style id=\"")
    @core.push_escaped(out, st.id)
    @core.push_lit(out, "\">")
    match st.line_color {
      Some(c) => {
        @core.push_lit(out, "<LineStyle><color>")
        @core.push_escaped(out, c)
        @core.push_lit(out, "</color>")
        match st.line_width {
          Some(w) => {
            @core.push_lit(out, "<width>")
            @core.push_double(out, w)
            @core.push_lit(out, "</width>")
          }
          None => ()
        }
        @core.push_lit(out, "</LineStyle>")
      }
      None => ()
    }
    match st.fill_color {
      Some(c) => {
        @core.push_lit(out, "<PolyStyle><color>")
        @core.push_escaped(out, c)
        @core.push_lit(out, "</color></PolyStyle>")
      }
      None => ()
    }
    match st.icon_href {
      Some(href) => {
        @core.push_lit(out, "<IconStyle>")
        match st.icon_scale {
          Some(sc) => {
            @core.push_lit(out, "<scale>")
            @core.push_double(out, sc)
            @core.push_lit(out, "</scale>")
          }
          None => ()
        }
        @core.push_lit(out, "<Icon><href>")
        @core.push_escaped(out, href)
        @core.push_lit(out, "</href></Icon></IconStyle>")
      }
      None => ()
    }
    match st.label_color {
      Some(c) => {
        @core.push_lit(out, "<LabelStyle><color>")
        @core.push_escaped(out, c)
        @core.push_lit(out, "</color>")
        match st.label_scale {
          Some(sc) => {
            @core.push_lit(out, "<scale>")
            @core.push_double(out, sc)
            @core.push_lit(out, "</scale>")
          }
          None => ()
        }
        @core.push_lit(out, "</LabelStyle>")
      }
      None => ()
    }
    @core.push_lit(out, "</Style>")
    i = i + 1
  }
  let mut sm = 0
  while sm < doc.style_maps.length() {
    @core.push_newline(out)
    let map = doc.style_maps[sm]
    @core.push_lit(out, "<StyleMap id=\"")
    @core.push_escaped(out, map.id)
    @core.push_lit(out, "\"><Pair><key>normal</key><styleUrl>")
    @core.push_escaped(out, map.normal)
    @core.push_lit(
      out, "</styleUrl></Pair><Pair><key>highlight</key><styleUrl>",
    )
    @core.push_escaped(out, map.highlight)
    @core.push_lit(out, "</styleUrl></Pair></StyleMap>")
    sm = sm + 1
  }
  let mut i = 0
  while i < doc.placemarks.length() {
    @core.push_newline(out)
    serialize_placemark(out, doc.placemarks[i])
    i = i + 1
  }
  @core.push_newline(out)
  @core.push_lit(out, "</Document>")
  @core.push_newline(out)
  @core.push_lit(out, "</kml>")
  @utf8.decode_lossy(Bytes::from_array(out))
}
