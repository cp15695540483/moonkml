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
  match doc.placemarks[0].point {
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
  match doc.placemarks[1].point {
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
  match doc.placemarks[0].point {
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
  match pm.line_string {
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
  match doc.placemarks[0].line_string {
    Some(ls) => assert_eq(ls.point_count(), 3)
    None => fail("expected line string")
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
