// KMZ 测试：ZIP 打包/解包与 KMZ round-trip。

///|
/// 一个简单文档。
fn kmz_sample_doc() -> KmlDocument {
  {
    name: "KMZ",
    styles: [],
    placemarks: [
      {
        name: "P",
        description: "",
        geometry: Some(Geometry::Point({ lon: 1.0, lat: 2.0, alt: None, })),
        style_url: "",
        extended_data: [],
      },
    ],
  }
}

///|
test "zip round-trips a single entry" {
  let entry : ZipEntry = { name: "doc.kml", data: @utf8.encode("hello"), }
  let packed = zip_pack([entry])
  match zip_find(packed, "doc.kml") {
    Some(data) => assert_eq(@utf8.decode_lossy(data), "hello")
    None => fail("expected doc.kml")
  }
}

///|
test "zip_find returns none for missing entry" {
  let packed = zip_pack([{ name: "a.txt", data: @utf8.encode("x"), }])
  assert_eq(zip_find(packed, "b.txt") is None, true)
}

///|
test "kmz round-trips document" {
  let doc = kmz_sample_doc()
  let bytes = kmz_pack(doc)
  let back = try! kmz_parse(bytes)
  assert_eq(back.name, "KMZ")
  assert_eq(back.placemark_count(), 1)
  match back.placemarks[0].geometry {
    Some(Geometry::Point(p)) => {
      assert_eq(p.lon, 1.0)
      assert_eq(p.lat, 2.0)
    }
    _ => fail("expected point")
  }
}

///|
test "kmz missing doc.kml raises" {
  let packed = zip_pack([{ name: "other.txt", data: @utf8.encode("x"), }])
  let failed = try {
    let _ = kmz_parse(packed)
    false
  } catch {
    BadCoordinates(_) => true
    _ => false
  }
  assert_eq(failed, true)
}

///|
test "crc32 known vector" {
  assert_eq(crc32(@utf8.encode("123456789")), 0xCBF43926)
}
