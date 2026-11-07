// 互操作测试：读取 simplekml（Python）生成的真实 deflate KMZ。
//
// 这段字节来自独立实现 simplekml 1.3.2 的 savekmz()，压缩算法为 DEFLATE，
// 用来验证我们的 ZIP 解包与 inflate 对第三方产物有效。

///|
/// simplekml 生成的 KMZ（394 字节）的十六进制表示。
fn oracle_kmz_hex() -> Array[String] {
  [
    "504b03041400000008004162675dd55186fd1a0100008002000007000000646f", "632e6b6d6c85924d6ec3201085f73e0562ed82719c268e30d9445d456aa4b607",
    "4078e4a2f063d9b4f6f1abd0a4b1ab345d8d98f7de309f806f476bd02774bdf6", "aec28c64188153bed6aea9f0dbebd3c31a6f45c28fd6a0d11ad757f83d847643",
    "e9300cc4b7e01add1307811eada139c9f1b76dd38c3367e37d6380286fa311c6", "10cd22410821bef3eac3820b48d71566e76e549cb4209e3ba90cecbce2349eaf",
    "f2c148055676c7985c4c92d7f481fd8e45ad865e75ba0dda3ba164ab83349c4e", "9b73fbc1ebf37e97ad67b2f2beabb593017ac1d8235994ab65ba284999ad5769",
    "51703a35cc27d3387a02457fa8fe245dde24dddf26dd6b072fa1d3ae89d9e2bf", "fdb3344b33922196b258f3343fd5bb0cd73bee80707a796891f0d33f10c91750",
    "4b010214001400000008004162675dd55186fd1a010000800200000700000000", "00000000000000800100000000646f632e6b6d6c504b05060000000001000100",
    "350000003f0100000000",
  ]
}

///|
/// 十六进制字符转半字节值。
fn hex_nibble(c : Byte) -> Int32 {
  let v = c.to_int()
  if v >= 48 && v <= 57 {
    v - 48
  } else if v >= 97 && v <= 102 {
    v - 87
  } else if v >= 65 && v <= 70 {
    v - 55
  } else {
    -1
  }
}

///|
/// 把十六进制行拼成字节数组。
fn oracle_kmz_bytes() -> Bytes {
  let out : Array[Byte] = []
  let lines = oracle_kmz_hex()
  let mut i = 0
  while i < lines.length() {
    let data = @utf8.encode(lines[i])
    let mut k = 0
    while k + 1 < data.length() {
      let hi = hex_nibble(data[k])
      let lo = hex_nibble(data[k + 1])
      out.push(((hi * 16 + lo) & 0xFF).to_byte())
      k = k + 2
    }
    i = i + 1
  }
  Bytes::from_array(out)
}

///|
test "parses deflate-compressed KMZ from simplekml" {
  let bytes = oracle_kmz_bytes()
  assert_eq(bytes.length(), 394)
  let doc = try! kmz_parse(bytes)
  assert_eq(doc.name, "OracleDoc")
  assert_eq(doc.placemark_count(), 2)
}

///|
test "oracle KMZ point and line match simplekml input" {
  let doc = try! kmz_parse(oracle_kmz_bytes())
  match doc.placemarks[0].geometry {
    Some(Geometry::Point(p)) => {
      assert_eq(p.lon, 116.3975)
      assert_eq(p.lat, 39.9087)
      match p.alt {
        Some(a) => assert_eq(a, 44.0)
        None => fail("expected altitude")
      }
    }
    _ => fail("expected point")
  }
  match doc.placemarks[1].geometry {
    Some(Geometry::LineString(ls)) => assert_eq(ls.point_count(), 3)
    _ => fail("expected line string")
  }
}

///|
test "oracle KMZ re-packs and re-reads" {
  let doc = try! kmz_parse(oracle_kmz_bytes())
  let repacked = kmz_pack(doc)
  let back = try! kmz_parse(repacked)
  assert_eq(back.placemark_count(), 2)
}
