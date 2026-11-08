// GPX 导入测试。

///|
test "imports waypoint" {
  let doc = try! from_gpx(
    "<?xml version=\"1.0\"?><gpx version=\"1.1\"><wpt lat=\"39.9\" lon=\"116.4\"><ele>50</ele><name>P</name></wpt></gpx>",
  )
  assert_eq(doc.placemark_count(), 1)
  assert_eq(doc.placemarks[0].name, "P")
  match doc.placemarks[0].geometry {
    Some(@core.Geometry::Point(p)) => {
      assert_eq(p.lat, 39.9)
      assert_eq(p.lon, 116.4)
      match p.alt {
        Some(a) => assert_eq(a, 50.0)
        None => fail("expected altitude")
      }
    }
    _ => fail("expected point")
  }
}

///|
test "imports route as linestring" {
  let doc = try! from_gpx(
    "<gpx><rte><name>R</name><rtept lat=\"0\" lon=\"0\"/><rtept lat=\"1\" lon=\"1\"/></rte></gpx>",
  )
  match doc.placemarks[0].geometry {
    Some(@core.Geometry::LineString(ls)) => assert_eq(ls.point_count(), 2)
    _ => fail("expected line string")
  }
}

///|
test "imports single-segment track" {
  let doc = try! from_gpx(
    "<gpx><trk><name>T</name><trkseg><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"1\" lon=\"1\"/></trkseg></trk></gpx>",
  )
  assert_eq(doc.placemarks[0].has_line_string(), true)
}

///|
test "imports multi-segment track as multi geometry" {
  let doc = try! from_gpx(
    "<gpx><trk><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg></trk></gpx>",
  )
  assert_eq(doc.placemarks[0].has_multi_geometry(), true)
}

///|
test "gpx round-trips through export" {
  let doc = try! from_gpx(
    "<gpx><wpt lat=\"39.9\" lon=\"116.4\"><name>P</name></wpt></gpx>",
  )
  let back = try! from_gpx(to_gpx(doc))
  assert_eq(back.placemark_count(), 1)
  assert_eq(back.placemarks[0].name, "P")
}

///|
test "non-gpx root raises" {
  let failed = try {
    let _ = from_gpx("<kml></kml>")
    false
  } catch {
    BadGpx(_) => true
    _ => false
  }
  assert_eq(failed, true)
}
