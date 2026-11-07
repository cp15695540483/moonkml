// 最小可运行示例：解析一段内嵌 KML 并打印结果。
// 运行：moon run cmd/main

///|
let sample : String = "<?xml version=\"1.0\"?>\n" +
  "<kml><Document><name>Demo</name>\n" +
  "<Placemark><name>Beijing</name>\n" +
  "<Point><coordinates>116.3975,39.9087,44</coordinates></Point>\n" +
  "</Placemark>\n" +
  "<Placemark><name>Shanghai</name>\n" +
  "<Point><coordinates>121.4737,31.2304</coordinates></Point>\n" +
  "</Placemark>\n" +
  "<Placemark><name>Track</name>\n" +
  "<LineString><coordinates>\n116.0,39.0,0 116.1,39.1 116.2,39.2\n</coordinates></LineString>\n" +
  "</Placemark>\n" +
  "<Placemark><name>Zone</name>\n" +
  "<Polygon><outerBoundaryIs><LinearRing><coordinates>\n0,0 4,0 4,4 0,4 0,0\n</coordinates></LinearRing></outerBoundaryIs></Polygon>\n" +
  "</Placemark>\n" +
  "</Document></kml>"

///|
fn main {
  let doc = try! @kml.parse(sample)
  println("document: " + doc.name)
  println("placemarks: " + doc.placemark_count().to_string())
  for pm in doc.placemarks {
    match pm.geometry {
      Some(@kml.Geometry::Point(p)) =>
        println(
          pm.name + " -> point " + p.lon.to_string() + ", " + p.lat.to_string(),
        )
      Some(@kml.Geometry::LineString(ls)) =>
        println(
          pm.name +
          " -> line with " +
          ls.point_count().to_string() +
          " vertices",
        )
      Some(@kml.Geometry::Polygon(poly)) =>
        println(
          pm.name +
          " -> polygon with " +
          poly.inner_count().to_string() +
          " holes",
        )
      None => println(pm.name + " -> (no geometry)")
    }
  }
}
