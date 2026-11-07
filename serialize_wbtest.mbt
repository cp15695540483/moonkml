// KML 序列化测试：覆盖 round-trip 与转义。

///|
/// 构造一个含三种几何的文档。
fn sample_doc() -> KmlDocument {
  {
    name: "Round",
    styles: [],
    placemarks: [
      {
        name: "P",
        description: "a <b> & c",
        geometry: Some(Geometry::Point({ lon: 1.5, lat: 2.5, alt: Some(3.0), })),
        style_url: "",
        extended_data: [],
      },
      {
        name: "L",
        description: "",
        style_url: "",
        extended_data: [],
        geometry: Some(
          Geometry::LineString({
            points: [
              { lon: 0.0, lat: 0.0, alt: None, },
              { lon: 1.0, lat: 1.0, alt: None, },
            ],
          }),
        ),
      },
      {
        name: "G",
        description: "",
        style_url: "",
        extended_data: [],
        geometry: Some(
          Geometry::Polygon({
            outer: {
              points: [
                { lon: 0.0, lat: 0.0, alt: None, },
                { lon: 1.0, lat: 0.0, alt: None, },
                { lon: 1.0, lat: 1.0, alt: None, },
                { lon: 0.0, lat: 0.0, alt: None, },
              ],
            },
            inner: [],
          }),
        ),
      },
    ],
  }
}

///|
test "serialize then parse round-trips placemarks" {
  let text = serialize(sample_doc())
  let back = try! parse(text)
  assert_eq(back.name, "Round")
  assert_eq(back.placemark_count(), 3)
}

///|
test "round-trip preserves point coordinates" {
  let text = serialize(sample_doc())
  let back = try! parse(text)
  match back.placemarks[0].geometry {
    Some(Geometry::Point(p)) => {
      assert_eq(p.lon, 1.5)
      assert_eq(p.lat, 2.5)
      match p.alt {
        Some(a) => assert_eq(a, 3.0)
        None => fail("expected altitude")
      }
    }
    _ => fail("expected point")
  }
}

///|
test "round-trip preserves line string" {
  let text = serialize(sample_doc())
  let back = try! parse(text)
  match back.placemarks[1].geometry {
    Some(Geometry::LineString(ls)) => assert_eq(ls.point_count(), 2)
    _ => fail("expected line string")
  }
}

///|
test "round-trip preserves polygon" {
  let text = serialize(sample_doc())
  let back = try! parse(text)
  match back.placemarks[2].geometry {
    Some(Geometry::Polygon(poly)) => {
      assert_eq(poly.outer.point_count(), 4)
      assert_eq(poly.inner_count(), 0)
    }
    _ => fail("expected polygon")
  }
}

///|
test "text is XML-escaped" {
  let text = serialize(sample_doc())
  let hay = @utf8.encode(text)
  assert_eq(hay.find(b"a &lt;b&gt; &amp; c") != None, true)
}

///|
test "empty geometry serializes to plain placemark" {
  let doc : KmlDocument = {
    name: "",
    styles: [],
    placemarks: [
      {
        name: "NoGeo",
        description: "",
        geometry: None,
        style_url: "",
        extended_data: [],
      },
    ],
  }
  let text = serialize(doc)
  let back = try! parse(text)
  assert_eq(back.placemarks[0].has_geometry(), false)
}
