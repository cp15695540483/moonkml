// KMZ 测试：ZIP 打包/解包与 KMZ round-trip。

///|
/// 一个简单文档。
fn kmz_sample_doc() -> KmlDocument {
  {
    name: "KMZ",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "P",
        description: "",
        geometry: Some(Geometry::Point({ lon: 1.0, lat: 2.0, alt: None, })),
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
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
test "lists multiple entries" {
  let packed = zip_pack([
    { name: "doc.kml", data: @utf8.encode("<kml/>"), },
    { name: "images/icon.png", data: @utf8.encode("PNGDATA"), },
  ])
  let names = try! kmz_entry_names(packed)
  assert_eq(names.length(), 2)
  assert_eq(names[1], "images/icon.png")
}

///|
test "extracts resource entry" {
  let packed = zip_pack([
    { name: "doc.kml", data: @utf8.encode("<kml/>"), },
    { name: "images/icon.png", data: @utf8.encode("PNGDATA"), },
  ])
  let found = try! kmz_extract(packed, "images/icon.png")
  match found {
    Some(data) => assert_eq(@utf8.decode_lossy(data), "PNGDATA")
    None => fail("expected resource")
  }
}

///|
test "packs document with resources" {
  let doc = kmz_sample_doc()
  let bytes = kmz_pack_with(doc, [
    { name: "images/icon.png", data: @utf8.encode("PNGDATA"), },
  ])
  let names = try! kmz_entry_names(bytes)
  assert_eq(names.length(), 2)
  let back = try! kmz_parse(bytes)
  assert_eq(back.placemark_count(), 1)
}

///|
test "falls back to first kml when doc.kml missing" {
  let packed = zip_pack([
    {
      name: "other.kml",
      data: @utf8.encode(
        "<kml><Placemark><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
      ),
    },
  ])
  let doc = try! kmz_parse(packed)
  assert_eq(doc.placemark_count(), 1)
}

///|
test "crc32 known vector" {
  assert_eq(crc32(@utf8.encode("123456789")), 0xCBF43926)
}
