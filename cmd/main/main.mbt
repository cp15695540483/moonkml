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
  "</Document></kml>"

///|
fn main {
  let doc = try! @kml.parse(sample)
  println("document: " + doc.name)
  println("placemarks: " + doc.placemark_count().to_string())
  for pm in doc.placemarks {
    match pm.point {
      Some(p) =>
        println(pm.name + " -> " + p.lon.to_string() + ", " + p.lat.to_string())
      None => println(pm.name + " -> (no point)")
    }
  }
}
