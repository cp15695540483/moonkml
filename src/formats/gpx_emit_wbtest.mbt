// GPX 导出测试。

///|
/// 一个含点、线的文档。
fn gpx_sample_doc() -> @core.KmlDocument {
  {
    name: "Trip",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "P",
        description: "",
        geometry: Some(
          @core.Geometry::Point({ lon: 1.0, lat: 2.0, alt: Some(3.0), }),
        ),
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
      {
        name: "L",
        description: "",
        geometry: Some(
          @core.Geometry::LineString({
            points: [
              { lon: 0.0, lat: 0.0, alt: Some(3.0), },
              { lon: 1.0, lat: 1.0, alt: None, },
            ],
          }),
        ),
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
    ],
  }
}

///|
test "gpx has waypoint and track" {
  let text = to_gpx(gpx_sample_doc())
  let data = @utf8.encode(text)
  assert_eq(data.find(b"<wpt lat=\"2\" lon=\"1\">") != None, true)
  assert_eq(data.find(b"<trk><trkseg>") != None, true)
}

///|
test "gpx includes altitude" {
  let text = to_gpx(gpx_sample_doc())
  let data = @utf8.encode(text)
  assert_eq(data.find(b"<ele>") != None, true)
}

///|
test "gpx escapes ampersand in name" {
  let doc : @core.KmlDocument = {
    name: "",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "A & B",
        description: "",
        geometry: Some(
          @core.Geometry::Point({ lon: 1.0, lat: 2.0, alt: None, }),
        ),
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
    ],
  }
  let text = to_gpx(doc)
  let data = @utf8.encode(text)
  assert_eq(data.find(b"A &amp; B") != None, true)
}
