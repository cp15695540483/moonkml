// KML 文档层测试：文档名、样式、扩展数据、Folder 路径与时间。

///|
/// 一个带两个 Placemark 的最小 KML。
fn sample_kml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n" +
  "  <Document>\n" +
  "    <name>Trip</name>\n" +
  "    <Placemark>\n" +
  "      <name>Beijing &amp; CBD</name>\n" +
  "      <description><![CDATA[Capital <b>center</b>]]></description>\n" +
  "      <Point><coordinates>116.3975,39.9087,44</coordinates></Point>\n" +
  "    </Placemark>\n" +
  "    <Placemark>\n" +
  "      <name>Shanghai</name>\n" +
  "      <Point><coordinates>121.4737,31.2304</coordinates></Point>\n" +
  "    </Placemark>\n" +
  "  </Document>\n" +
  "</kml>"
}

// KML 几何层测试：坐标、折线、环、多重几何、gx:Track 与解析错误。

///|
test "document name and placemark count" {
  let doc = try! parse(sample_kml())
  assert_eq(doc.name, "Trip")
  assert_eq(doc.placemark_count(), 2)
}

///|
test "first placemark fields" {
  let doc = try! parse(sample_kml())
  let pm = doc.placemarks[0]
  assert_eq(pm.name, "Beijing & CBD")
  assert_eq(pm.description, "Capital <b>center</b>")
  assert_eq(pm.has_point(), true)
}

///|
test "comments and processing instructions are ignored" {
  let doc = try! parse(
    "<?xml version=\"1.0\"?><!-- hi --><kml><Document><Placemark><name>A</name>" +
    "<Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  assert_eq(doc.placemark_count(), 1)
  assert_eq(doc.placemarks[0].name, "A")
}

///|
test "style is parsed with line and poly colors" {
  let doc = try! parse(
    "<kml><Document>\n" +
    "<Style id=\"road\"><LineStyle><color>ff0000ff</color><width>3</width></LineStyle><PolyStyle><color>7f00ff00</color></PolyStyle></Style>\n" +
    "<Placemark><name>R</name><styleUrl>#road</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark>\n" +
    "</Document></kml>",
  )
  assert_eq(doc.style_count(), 1)
  assert_eq(doc.placemarks[0].style_url, "#road")
  match doc.find_style("road") {
    Some(st) => {
      assert_eq(st.line_color, Some("ff0000ff"))
      assert_eq(st.line_width, Some(3.0))
      assert_eq(st.fill_color, Some("7f00ff00"))
    }
    None => fail("expected style")
  }
}

///|
test "style round-trips" {
  let doc = try! parse(
    "<kml><Document><Style id=\"s1\"><LineStyle><color>ff0000ff</color><width>2</width></LineStyle></Style><Placemark><name>P</name><styleUrl>#s1</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  let text = serialize(doc)
  let back = try! parse(text)
  assert_eq(back.style_count(), 1)
  assert_eq(back.placemarks[0].style_url, "#s1")
}

///|
test "extended data is parsed" {
  let doc = try! parse(
    "<kml><Placemark><name>P</name>\n" +
    "<ExtendedData><Data name=\"type\"><value>school</value></Data><Data name=\"count\"><value>42</value></Data></ExtendedData>\n" +
    "<Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  assert_eq(doc.placemarks[0].data_count(), 2)
  assert_eq(doc.placemarks[0].find_data("type"), Some("school"))
  assert_eq(doc.placemarks[0].find_data("count"), Some("42"))
}

///|
test "extended data round-trips" {
  let doc = try! parse(
    "<kml><Placemark><ExtendedData><Data name=\"a\"><value>1</value></Data></ExtendedData><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  let back = try! parse(serialize(doc))
  assert_eq(back.placemarks[0].find_data("a"), Some("1"))
}

///|
test "style map is parsed" {
  let doc = try! parse(
    "<kml><Document>\n" +
    "<Style id=\"n\"><LineStyle><color>ff0000ff</color></LineStyle></Style>\n" +
    "<StyleMap id=\"m\"><Pair><key>normal</key><styleUrl>#n</styleUrl></Pair><Pair><key>highlight</key><styleUrl>#h</styleUrl></Pair></StyleMap>\n" +
    "<Placemark><name>P</name><styleUrl>#m</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark>\n" +
    "</Document></kml>",
  )
  assert_eq(doc.style_map_count(), 1)
  match doc.find_style_map("m") {
    Some(map) => {
      assert_eq(map.normal, "#n")
      assert_eq(map.highlight, "#h")
    }
    None => fail("expected style map")
  }
}

///|
test "style map round-trips" {
  let doc = try! parse(
    "<kml><Document><StyleMap id=\"m\"><Pair><key>normal</key><styleUrl>#n</styleUrl></Pair></StyleMap><Placemark><name>P</name><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  let back = try! parse(serialize(doc))
  assert_eq(back.style_map_count(), 1)
  match back.find_style_map("m") {
    Some(map) => assert_eq(map.normal, "#n")
    None => fail("expected style map")
  }
}

///|
test "folder path is recorded" {
  let doc = try! parse(
    "<kml><Document><Folder><name>A</name><Folder><name>B</name><Placemark><name>P</name><Point><coordinates>1,2</coordinates></Point></Placemark></Folder></Folder></Document></kml>",
  )
  assert_eq(doc.placemarks[0].folder, "A/B")
}

///|
test "top-level placemark has empty folder" {
  let doc = try! parse(
    "<kml><Document><Placemark><name>P</name><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  assert_eq(doc.placemarks[0].folder, "")
}

///|
test "timestamp is parsed and round-trips" {
  let doc = try! parse(
    "<kml><Placemark><TimeStamp><when>2020-01-01T00:00:00Z</when></TimeStamp><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  assert_eq(doc.placemarks[0].has_time(), true)
  match doc.placemarks[0].timestamp {
    Some(ts) => assert_eq(ts.when, "2020-01-01T00:00:00Z")
    None => fail("expected timestamp")
  }
  let back = try! parse(serialize(doc))
  match back.placemarks[0].timestamp {
    Some(ts) => assert_eq(ts.when, "2020-01-01T00:00:00Z")
    None => fail("expected timestamp after round-trip")
  }
}

///|
test "time span is parsed" {
  let doc = try! parse(
    "<kml><Placemark><TimeSpan><begin>b</begin><end>e</end></TimeSpan><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  match doc.placemarks[0].timestamp {
    Some(ts) => {
      assert_eq(ts.begin, "b")
      assert_eq(ts.end, "e")
      assert_eq(ts.when, "")
    }
    None => fail("expected time span")
  }
}

///|
test "icon and label style are parsed" {
  let doc = try! parse(
    "<kml><Document>\n" +
    "<Style id=\"s\"><IconStyle><color>ffffffff</color><scale>1.5</scale><Icon><href>http://x/i.png</href></Icon></IconStyle><LabelStyle><color>ff00ff00</color><scale>2</scale></LabelStyle></Style>\n" +
    "<Placemark><name>P</name><styleUrl>#s</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark>\n" +
    "</Document></kml>",
  )
  match doc.find_style("s") {
    Some(st) => {
      assert_eq(st.icon_href, Some("http://x/i.png"))
      assert_eq(st.icon_scale, Some(1.5))
      assert_eq(st.label_color, Some("ff00ff00"))
      assert_eq(st.label_scale, Some(2.0))
    }
    None => fail("expected style")
  }
}

///|
test "icon style round-trips" {
  let doc = try! parse(
    "<kml><Document><Style id=\"s\"><IconStyle><scale>1.5</scale><Icon><href>i.png</href></Icon></IconStyle></Style><Placemark><name>P</name><styleUrl>#s</styleUrl><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>",
  )
  let back = try! parse(serialize(doc))
  match back.find_style("s") {
    Some(st) => assert_eq(st.icon_href, Some("i.png"))
    None => fail("expected style after round-trip")
  }
}
