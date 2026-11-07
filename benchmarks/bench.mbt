// 解析、序列化与 KMZ 的基准测试。
// 运行：moon bench benchmarks --target wasm-gc --release

///|
/// 生成含 n 个点 Placemark 的 KML 文本。
fn make_kml(n : Int32) -> String {
  let out : Array[Byte] = []
  let head = @utf8.encode(
    "<?xml version=\"1.0\"?><kml><Document><name>Bench</name>",
  )
  let mut i = 0
  while i < head.length() {
    out.push(head[i])
    i = i + 1
  }
  let mut k = 0
  while k < n {
    let d = @utf8.encode(
      "<Placemark><name>P" +
      k.to_string() +
      "</name><Point><coordinates>116.4,39.9,50</coordinates></Point></Placemark>",
    )
    let mut j = 0
    while j < d.length() {
      out.push(d[j])
      j = j + 1
    }
    k = k + 1
  }
  let tail = @utf8.encode("</Document></kml>")
  let mut t = 0
  while t < tail.length() {
    out.push(tail[t])
    t = t + 1
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

///|
test "bench parse 1000 placemarks" (b : @bench.T) {
  let text = make_kml(1000)
  b.bench(name="parse-1000", () => {
    let doc = @kml.parse(text) catch { _ => abort("parse failed") }
    b.keep(doc.placemark_count())
  })
}

///|
test "bench serialize 1000 placemarks" (b : @bench.T) {
  let doc = @kml.parse(make_kml(1000)) catch { _ => abort("parse failed") }
  b.bench(name="serialize-1000", () => b.keep(@kml.serialize(doc).length()))
}

///|
test "bench kmz pack and parse" (b : @bench.T) {
  let doc = @kml.parse(make_kml(200)) catch { _ => abort("parse failed") }
  b.bench(name="kmz-pack", () => b.keep(@kml.kmz_pack(doc).length()))
  let bytes = @kml.kmz_pack(doc)
  b.bench(name="kmz-parse", () => {
    let back = @kml.kmz_parse(bytes) catch { _ => abort("kmz parse failed") }
    b.keep(back.placemark_count())
  })
}
