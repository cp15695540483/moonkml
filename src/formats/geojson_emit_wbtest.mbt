// GeoJSON 导出测试。

///|
/// 一个含点、线、面的文档。
fn geo_sample_doc() -> @core.KmlDocument {
  {
    name: "Geo",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "P",
        description: "point",
        geometry: Some(
          @core.Geometry::Point({ lon: 1.0, lat: 2.0, alt: None, }),
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
              { lon: 0.0, lat: 0.0, alt: None, },
              { lon: 1.0, lat: 1.0, alt: None, },
            ],
          }),
        ),
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
      {
        name: "G",
        description: "",
        geometry: Some(
          @core.Geometry::Polygon({
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
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
    ],
  }
}

///|
test "geojson has three features" {
  let text = to_geojson(geo_sample_doc())
  let data = @utf8.encode(text)
  let mut count = 0
  let mut i = 0
  while i + 9 <= data.length() {
    if data[i] == b'"' &&
      data[i + 1] == b't' &&
      data[i + 2] == b'y' &&
      data[i + 3] == b'p' &&
      data[i + 4] == b'e' &&
      data[i + 5] == b'"' {
      count = count + 1
    }
    i = i + 1
  }
  assert_eq(count, 7)
}

///|
test "geojson contains point coordinates" {
  let text = to_geojson(geo_sample_doc())
  let data = @utf8.encode(text)
  assert_eq(data.find(b"\"coordinates\":[1,2]") != None, true)
}

///|
test "geojson escapes quotes in name" {
  let doc : @core.KmlDocument = {
    name: "",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "a\"b",
        description: "",
        geometry: None,
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
    ],
  }
  let text = to_geojson(doc)
  let data = @utf8.encode(text)
  assert_eq(data.find(b"a\\\"b") != None, true)
}
