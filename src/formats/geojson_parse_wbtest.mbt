// GeoJSON 导入测试。

///|
test "imports FeatureCollection with point and linestring" {
  let doc = try! from_geojson(
    "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"P\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[116.4,39.9,50]}},{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}}]}",
  )
  assert_eq(doc.placemark_count(), 2)
  assert_eq(doc.placemarks[0].name, "P")
  match doc.placemarks[0].geometry {
    Some(@core.Geometry::Point(p)) => {
      assert_eq(p.lon, 116.4)
      assert_eq(p.lat, 39.9)
      match p.alt {
        Some(a) => assert_eq(a, 50.0)
        None => fail("expected altitude")
      }
    }
    _ => fail("expected point")
  }
  match doc.placemarks[1].geometry {
    Some(@core.Geometry::LineString(ls)) => assert_eq(ls.point_count(), 2)
    _ => fail("expected line string")
  }
}

///|
test "imports polygon with hole" {
  let doc = try! from_geojson(
    "{\"type\":\"Feature\",\"properties\":{\"name\":\"Z\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[4,0],[4,4],[0,0]],[[1,1],[2,1],[2,2],[1,1]]]}}",
  )
  match doc.placemarks[0].geometry {
    Some(@core.Geometry::Polygon(poly)) => {
      assert_eq(poly.outer.point_count(), 4)
      assert_eq(poly.inner_count(), 1)
    }
    _ => fail("expected polygon")
  }
}

///|
test "imports multi geometry" {
  let doc = try! from_geojson(
    "{\"type\":\"MultiPoint\",\"coordinates\":[[1,2],[3,4]]}",
  )
  match doc.placemarks[0].geometry {
    Some(@core.Geometry::MultiGeometry(parts)) => assert_eq(parts.length(), 2)
    _ => fail("expected multi geometry")
  }
}

///|
test "geojson round-trips through export" {
  let doc = try! from_geojson(
    "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"P\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[116.4,39.9]}}]}",
  )
  let back = try! from_geojson(to_geojson(doc))
  assert_eq(back.placemark_count(), 1)
  assert_eq(back.placemarks[0].name, "P")
}

///|
test "invalid geojson raises" {
  let failed = try {
    let _ = from_geojson("{not json")
    false
  } catch {
    BadGeoJson(_) => true
    _ => false
  }
  assert_eq(failed, true)
}

///|
test "gx track exports to geojson linestring and gpx track" {
  let track : @core.KmlGxTrack = {
    whens: [],
    coords: [
      { lon: 1.0, lat: 2.0, alt: None, },
      { lon: 3.0, lat: 4.0, alt: None, },
    ],
  }
  let doc : @core.KmlDocument = {
    name: "",
    styles: [],
    style_maps: [],
    placemarks: [
      {
        name: "T",
        description: "",
        geometry: Some(@core.Geometry::GxTrack(track)),
        style_url: "",
        extended_data: [],
        folder: "",
        timestamp: None,
      },
    ],
  }
  let gj = @utf8.encode(to_geojson(doc))
  assert_eq(gj.find(b"\"LineString\"") != None, true)
  let gx = @utf8.encode(to_gpx(doc))
  assert_eq(gx.find(b"<trkseg>") != None, true)
}
