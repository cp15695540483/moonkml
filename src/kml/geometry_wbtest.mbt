// KML 几何层测试：坐标、折线、环、多重几何、gx:Track 与解析错误。

///|
/// 浮点比较：解析用十进制累加，允许几个 ULP 的误差。
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  let diff = (actual - expected).abs()
  assert_true(diff <= 1.0e-9)
}

///|
/// 取出 Placemark 的 Point 几何。
fn point_of(pm : @core.Placemark) -> @core.KmlPoint? {
  match pm.geometry {
    Some(@core.Geometry::Point(p)) => Some(p)
    _ => None
  }
}

///|
/// 取出 Placemark 的 LineString 几何。
fn line_of(pm : @core.Placemark) -> @core.KmlLineString? {
  match pm.geometry {
    Some(@core.Geometry::LineString(ls)) => Some(ls)
    _ => None
  }
}

///|
/// 取出 Placemark 的 Polygon 几何。
fn polygon_of(pm : @core.Placemark) -> @core.KmlPolygon? {
  match pm.geometry {
    Some(@core.Geometry::Polygon(poly)) => Some(poly)
    _ => None
  }
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
    Some(@core.Geometry::MultiGeometry(geoms)) => assert_eq(geoms.length(), 2)
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
    Some(@core.Geometry::GxTrack(track)) => {
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
    Some(@core.Geometry::GxTrack(track)) => assert_eq(track.point_count(), 1)
    _ => fail("expected gx track")
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
