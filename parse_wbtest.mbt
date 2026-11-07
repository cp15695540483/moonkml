// KML 解析测试：每条用例对应一个真实文档形态。

///|
/// 一个带两个 Placemark 的最小 KML。
fn sample_kml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n" +
  "  <Document>\n" +
  "    <name>Trip</name>\n" +
  "    <Placemark>\n" +
  "      <name>Beijing &amp; CBD</name>\n" +
  "      <description><![CDATA[Capital <b>center</b>]]></description>\n" +
  "      <Point><coordinates>116.3975,39.9087,44</coordinates></Point>\n" +
  "    </Placemark>\n" +
  "    <Placemark>\n" +
  "      <name>Shanghai</name>\n" +
  "      <Point><coordinates>121.4737,31.2304</coordinates></Point>\n" +
  "    </Placemark>\n" +
  "  </Document>\n" +
  "</kml>"
}

///|
/// 浮点比较：解析用十进制累加，允许几个 ULP 的误差。
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  let diff = (actual - expected).abs()
  assert_true(diff <= 1.0e-9)
}

///|
/// 取出 Placemark 的 Point 几何。
fn point_of(pm : Placemark) -> KmlPoint? {
  match pm.geometry {
    Some(Geometry::Point(p)) => Some(p)
    _ => None
  }
}

///|
/// 取出 Placemark 的 LineString 几何。
fn line_of(pm : Placemark) -> KmlLineString? {
  match pm.geometry {
    Some(Geometry::LineString(ls)) => Some(ls)
    _ => None
  }
}

///|
/// 取出 Placemark 的 Polygon 几何。
fn polygon_of(pm : Placemark) -> KmlPolygon? {
  match pm.geometry {
    Some(Geometry::Polygon(poly)) => Some(poly)
    _ => None
  }
}

///|
test "document name and placemark count" {
  let doc = try! parse(sample_kml())
  assert_eq(doc.name, "Trip")
  assert_eq(doc.placemark_count(), 2)
}

///|
test "first placemark fields" {
  let doc = try! parse(sample_kml())
  let pm = doc.placemarks[0]
  assert_eq(pm.name, "Beijing & CBD")
  assert_eq(pm.description, "Capital <b>center</b>")
  assert_eq(pm.has_point(), true)
}

///|
test "coordinates with altitude" {
  let doc = try! parse(sample_kml())
  match point_of(doc.placemarks[0]) {
    Some(p) => {
      assert_close(p.lon, 116.3975)
      assert_close(p.lat, 39.9087)
      match p.alt {
        Some(a) => assert_close(a, 44.0)
        None => fail("expected altitude")
      }
    }
    None => fail("expected point")
  }
}

///|
test "coordinates without altitude" {
  let doc = try! parse(sample_kml())
  match point_of(doc.placemarks[1]) {
    Some(p) => assert_eq(p.alt is None, true)
    None => fail("expected point")
  }
}

///|
test "comments and processing instructions are ignored" {
  let doc = try! parse(
    "<?xml version=\"1.0\"?><!-- hi --><kml><Document><Placemark><name>A</name>" +
    "<Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  assert_eq(doc.placemark_count(), 1)
  assert_eq(doc.placemarks[0].name, "A")
}

///|
test "whitespace around coordinates is trimmed" {
  let doc = try! parse(
    "<kml><Placemark><Point><coordinates> 1.5 , 2.5 </coordinates></Point></Placemark></kml>",
  )
  match point_of(doc.placemarks[0]) {
    Some(p) => {
      assert_close(p.lon, 1.5)
      assert_close(p.lat, 2.5)
    }
    None => fail("expected point")
  }
}

///|
/// 一条折线的 KML 片段。
fn sample_line_kml() -> String {
  "<kml><Document><Placemark><name>Path</name>\n" +
  "<LineString><coordinates>\n" +
  "  0,0,0 1,1 2,2,5\n" +
  "</coordinates></LineString>\n" +
  "</Placemark></Document></kml>"
}

///|
test "line string is parsed with whitespace-separated points" {
  let doc = try! parse(sample_line_kml())
  assert_eq(doc.placemark_count(), 1)
  let pm = doc.placemarks[0]
  assert_eq(pm.has_line_string(), true)
  assert_eq(pm.has_point(), false)
  match line_of(pm) {
    Some(ls) => {
      assert_eq(ls.point_count(), 3)
      assert_close(ls.points[0].lon, 0.0)
      assert_close(ls.points[0].lat, 0.0)
      assert_close(ls.points[2].lon, 2.0)
      assert_close(ls.points[2].lat, 2.0)
      match ls.points[2].alt {
        Some(a) => assert_close(a, 5.0)
        None => fail("expected altitude on third vertex")
      }
    }
    None => fail("expected line string")
  }
}

///|
test "line string with newline-separated tuples" {
  let doc = try! parse(
    "<kml><Placemark><LineString><coordinates>1,2\n3,4\n5,6</coordinates></LineString></Placemark></kml>",
  )
  match line_of(doc.placemarks[0]) {
    Some(ls) => assert_eq(ls.point_count(), 3)
    None => fail("expected line string")
  }
}

///|
/// 一个带洞的多边形 KML。
fn sample_polygon_kml() -> String {
  "<kml><Placemark><name>Zone</name>\n" +
  "<Polygon>\n" +
  "  <outerBoundaryIs><LinearRing><coordinates>0,0 4,0 4,4 0,4 0,0</coordinates></LinearRing></outerBoundaryIs>\n" +
  "  <innerBoundaryIs><LinearRing><coordinates>1,1 2,1 2,2 1,2 1,1</coordinates></LinearRing></innerBoundaryIs>\n" +
  "</Polygon>\n" +
  "</Placemark></kml>"
}

///|
test "polygon with outer ring and one hole" {
  let doc = try! parse(sample_polygon_kml())
  match polygon_of(doc.placemarks[0]) {
    Some(poly) => {
      assert_eq(poly.outer.point_count(), 5)
      assert_eq(poly.inner_count(), 1)
      assert_eq(poly.inner[0].point_count(), 5)
    }
    None => fail("expected polygon")
  }
}

///|
test "polygon without inner boundary" {
  let doc = try! parse(
    "<kml><Placemark><Polygon><outerBoundaryIs><LinearRing><coordinates>0,0 1,0 1,1 0,0</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark></kml>",
  )
  match polygon_of(doc.placemarks[0]) {
    Some(poly) => assert_eq(poly.inner_count(), 0)
    None => fail("expected polygon")
  }
}

///|
test "multi geometry collects sub-geometries" {
  let doc = try! parse(
    "<kml><Placemark><MultiGeometry><Point><coordinates>1,2</coordinates></Point><LineString><coordinates>1,2 3,4</coordinates></LineString></MultiGeometry></Placemark></kml>",
  )
  assert_eq(doc.placemarks[0].has_multi_geometry(), true)
  match doc.placemarks[0].geometry {
    Some(Geometry::MultiGeometry(geoms)) => assert_eq(geoms.length(), 2)
    _ => fail("expected multi geometry")
  }
}

///|
test "multi geometry round-trips" {
  let text = serialize(
    try! parse(
      "<kml><Placemark><MultiGeometry><Point><coordinates>1,2</coordinates></Point></MultiGeometry></Placemark></kml>",
    ),
  )
  let back = try! parse(text)
  assert_eq(back.placemarks[0].has_multi_geometry(), true)
}

///|
test "style is parsed with line and poly colors" {
  let doc = try! parse(
    "<kml><Document>\n" +
    "<Style id=\"road\"><LineStyle><color>ff0000ff</color><width>3</width></LineStyle><PolyStyle><color>7f00ff00</color></PolyStyle></Style>\n" +
    "<Placemark><name>R</name><styleUrl>#road</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark>\n" +
    "</Document></kml>",
  )
  assert_eq(doc.style_count(), 1)
  assert_eq(doc.placemarks[0].style_url, "#road")
  match doc.find_style("road") {
    Some(st) => {
      assert_eq(st.line_color, Some("ff0000ff"))
      assert_eq(st.line_width, Some(3.0))
      assert_eq(st.fill_color, Some("7f00ff00"))
    }
    None => fail("expected style")
  }
}

///|
test "style round-trips" {
  let doc = try! parse(
    "<kml><Document><Style id=\"s1\"><LineStyle><color>ff0000ff</color><width>2</width></LineStyle></Style><Placemark><name>P</name><styleUrl>#s1</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  let text = serialize(doc)
  let back = try! parse(text)
  assert_eq(back.style_count(), 1)
  assert_eq(back.placemarks[0].style_url, "#s1")
}

///|
test "extended data is parsed" {
  let doc = try! parse(
    "<kml><Placemark><name>P</name>\n" +
    "<ExtendedData><Data name=\"type\"><value>school</value></Data><Data name=\"count\"><value>42</value></Data></ExtendedData>\n" +
    "<Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  assert_eq(doc.placemarks[0].data_count(), 2)
  assert_eq(doc.placemarks[0].find_data("type"), Some("school"))
  assert_eq(doc.placemarks[0].find_data("count"), Some("42"))
}

///|
test "extended data round-trips" {
  let doc = try! parse(
    "<kml><Placemark><ExtendedData><Data name=\"a\"><value>1</value></Data></ExtendedData><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  let back = try! parse(serialize(doc))
  assert_eq(back.placemarks[0].find_data("a"), Some("1"))
}

///|
test "style map is parsed" {
  let doc = try! parse(
    "<kml><Document>\n" +
    "<Style id=\"n\"><LineStyle><color>ff0000ff</color></LineStyle></Style>\n" +
    "<StyleMap id=\"m\"><Pair><key>normal</key><styleUrl>#n</styleUrl></Pair><Pair><key>highlight</key><styleUrl>#h</styleUrl></Pair></StyleMap>\n" +
    "<Placemark><name>P</name><styleUrl>#m</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark>\n" +
    "</Document></kml>",
  )
  assert_eq(doc.style_map_count(), 1)
  match doc.find_style_map("m") {
    Some(map) => {
      assert_eq(map.normal, "#n")
      assert_eq(map.highlight, "#h")
    }
    None => fail("expected style map")
  }
}

///|
test "style map round-trips" {
  let doc = try! parse(
    "<kml><Document><StyleMap id=\"m\"><Pair><key>normal</key><styleUrl>#n</styleUrl></Pair></StyleMap><Placemark><name>P</name><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  let back = try! parse(serialize(doc))
  assert_eq(back.style_map_count(), 1)
  match back.find_style_map("m") {
    Some(map) => assert_eq(map.normal, "#n")
    None => fail("expected style map")
  }
}

///|
test "gx track is parsed with when and coord" {
  let doc = try! parse(
    "<kml><Placemark><name>T</name>\n" +
    "<gx:Track>\n" +
    "<when>2020-01-01T00:00:00Z</when><gx:coord>116.0 39.0 10</gx:coord>\n" +
    "<when>2020-01-01T00:00:01Z</when><gx:coord>116.1 39.1 11</gx:coord>\n" +
    "</gx:Track></Placemark></kml>",
  )
  assert_eq(doc.placemarks[0].has_gx_track(), true)
  match doc.placemarks[0].geometry {
    Some(Geometry::GxTrack(track)) => {
      assert_eq(track.point_count(), 2)
      assert_eq(track.whens.length(), 2)
      assert_close(track.coords[1].lon, 116.1)
      match track.coords[1].alt {
        Some(a) => assert_close(a, 11.0)
        None => fail("expected altitude")
      }
    }
    _ => fail("expected gx track")
  }
}

///|
test "gx track round-trips" {
  let doc = try! parse(
    "<kml><Placemark><gx:Track><when>t0</when><gx:coord>1 2 3</gx:coord></gx:Track></Placemark></kml>",
  )
  let back = try! parse(serialize(doc))
  assert_eq(back.placemarks[0].has_gx_track(), true)
  match back.placemarks[0].geometry {
    Some(Geometry::GxTrack(track)) => assert_eq(track.point_count(), 1)
    _ => fail("expected gx track")
  }
}

///|
test "gx track exports to geojson linestring and gpx track" {
  let doc = try! parse(
    "<kml><Placemark><gx:Track><gx:coord>1 2 0</gx:coord><gx:coord>3 4 0</gx:coord></gx:Track></Placemark></kml>",
  )
  let gj = @utf8.encode(to_geojson(doc))
  assert_eq(gj.find(b"\"LineString\"") != None, true)
  let gx = @utf8.encode(to_gpx(doc))
  assert_eq(gx.find(b"<trkseg>") != None, true)
}

///|
test "folder path is recorded" {
  let doc = try! parse(
    "<kml><Document><Folder><name>A</name><Folder><name>B</name><Placemark><name>P</name><Point><coordinates>1,2</coordinates></Point></Placemark></Folder></Folder></Document></kml>",
  )
  assert_eq(doc.placemarks[0].folder, "A/B")
}

///|
test "top-level placemark has empty folder" {
  let doc = try! parse(
    "<kml><Document><Placemark><name>P</name><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  assert_eq(doc.placemarks[0].folder, "")
}

///|
test "timestamp is parsed and round-trips" {
  let doc = try! parse(
    "<kml><Placemark><TimeStamp><when>2020-01-01T00:00:00Z</when></TimeStamp><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  assert_eq(doc.placemarks[0].has_time(), true)
  match doc.placemarks[0].timestamp {
    Some(ts) => assert_eq(ts.when, "2020-01-01T00:00:00Z")
    None => fail("expected timestamp")
  }
  let back = try! parse(serialize(doc))
  match back.placemarks[0].timestamp {
    Some(ts) => assert_eq(ts.when, "2020-01-01T00:00:00Z")
    None => fail("expected timestamp after round-trip")
  }
}

///|
test "time span is parsed" {
  let doc = try! parse(
    "<kml><Placemark><TimeSpan><begin>b</begin><end>e</end></TimeSpan><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  match doc.placemarks[0].timestamp {
    Some(ts) => {
      assert_eq(ts.begin, "b")
      assert_eq(ts.end, "e")
      assert_eq(ts.when, "")
    }
    None => fail("expected time span")
  }
}

///|
test "icon and label style are parsed" {
  let doc = try! parse(
    "<kml><Document>\n" +
    "<Style id=\"s\"><IconStyle><color>ffffffff</color><scale>1.5</scale><Icon><href>http://x/i.png</href></Icon></IconStyle><LabelStyle><color>ff00ff00</color><scale>2</scale></LabelStyle></Style>\n" +
    "<Placemark><name>P</name><styleUrl>#s</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark>\n" +
    "</Document></kml>",
  )
  match doc.find_style("s") {
    Some(st) => {
      assert_eq(st.icon_href, Some("http://x/i.png"))
      assert_eq(st.icon_scale, Some(1.5))
      assert_eq(st.label_color, Some("ff00ff00"))
      assert_eq(st.label_scale, Some(2.0))
    }
    None => fail("expected style")
  }
}

///|
test "icon style round-trips" {
  let doc = try! parse(
    "<kml><Document><Style id=\"s\"><IconStyle><scale>1.5</scale><Icon><href>i.png</href></Icon></IconStyle></Style><Placemark><name>P</name><styleUrl>#s</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  let back = try! parse(serialize(doc))
  match back.find_style("s") {
    Some(st) => assert_eq(st.icon_href, Some("i.png"))
    None => fail("expected style after round-trip")
  }
}

///|
test "missing coordinates raises" {
  let failed = try {
    let _ = parse("<kml><Placemark><Point></Point></Placemark></kml>")
    false
  } catch {
    MissingCoordinates => true
    _ => false
  }
  assert_eq(failed, true)
}

///|
test "bad coordinates raises" {
  let failed = try {
    let _ = parse(
      "<kml><Placemark><Point><coordinates>a,b</coordinates></Point></Placemark></kml>",
    )
    false
  } catch {
    BadCoordinates(_) => true
    _ => false
  }
  assert_eq(failed, true)
}

///|
test "unclosed element raises" {
  let failed = try {
    let _ = parse("<kml><Placemark>")
    false
  } catch {
    XmlUnclosed(_, _) => true
    _ => false
  }
  assert_eq(failed, true)
}

///|
test "mismatched end tag raises" {
  let failed = try {
    let _ = parse("<kml><a></b></kml>")
    false
  } catch {
    XmlMismatch(_, _, _) => true
    _ => false
  }
  assert_eq(failed, true)
}
