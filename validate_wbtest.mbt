// 文档校验测试。

///|
/// 构造一个只含给定几何的文档。
fn doc_with(geometry : Geometry?) -> KmlDocument {
  {
    name: "",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "X",
        description: "",
        geometry,
        style_url: "",
        extended_data: [],
      },
    ],
  }
}

///|
test "valid point passes" {
  let issues = validate(
    doc_with(Some(Geometry::Point({ lon: 116.4, lat: 39.9, alt: None, }))),
  )
  assert_eq(issues.length(), 0)
}

///|
test "out-of-range point is reported" {
  let issues = validate(
    doc_with(Some(Geometry::Point({ lon: 200.0, lat: 39.9, alt: None, }))),
  )
  assert_eq(issues.length(), 1)
}

///|
test "unclosed ring is reported" {
  let ring : LinearRing = {
    points: [
      { lon: 0.0, lat: 0.0, alt: None, },
      { lon: 1.0, lat: 0.0, alt: None, },
      { lon: 1.0, lat: 1.0, alt: None, },
      { lon: 0.5, lat: 0.5, alt: None, },
    ],
  }
  let issues = validate(
    doc_with(Some(Geometry::Polygon({ outer: ring, inner: [], }))),
  )
  assert_eq(issues.length(), 1)
}

///|
test "short line string is reported" {
  let issues = validate(
    doc_with(
      Some(
        Geometry::LineString({ points: [{ lon: 0.0, lat: 0.0, alt: None, }], }),
      ),
    ),
  )
  assert_eq(issues.length(), 1)
}

///|
test "missing geometry is reported" {
  let issues = validate(doc_with(None))
  assert_eq(issues.length(), 1)
}

///|
test "gx track timestamp mismatch is reported" {
  let track : KmlGxTrack = {
    whens: ["t0", "t1"],
    coords: [{ lon: 1.0, lat: 2.0, alt: None, }],
  }
  let issues = validate(doc_with(Some(Geometry::GxTrack(track))))
  assert_eq(issues.length(), 1)
}

///|
test "dangling style reference is reported" {
  let doc : KmlDocument = {
    name: "",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "X",
        description: "",
        geometry: Some(Geometry::Point({ lon: 1.0, lat: 2.0, alt: None, })),
        style_url: "#missing",
        extended_data: [],
      },
    ],
  }
  let issues = validate(doc)
  assert_eq(issues.length(), 1)
}

///|
test "resolvable style reference passes" {
  let doc : KmlDocument = {
    name: "",
    styles: [{ id: "s", line_color: None, line_width: None, fill_color: None, }],
    style_maps: [],
    placemarks: [
      {
        name: "X",
        description: "",
        geometry: Some(Geometry::Point({ lon: 1.0, lat: 2.0, alt: None, })),
        style_url: "#s",
        extended_data: [],
      },
    ],
  }
  assert_eq(validate(doc).length(), 0)
}
