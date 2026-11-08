# moonkml

纯 MoonBit 实现的 [KML 2.2](https://www.ogc.org/standards/kml) 读写库。零 FFI，可运行在 `wasm-gc`、`js` 与 `native` 后端。

KML 是 Google Earth、无人机航迹、GPS 轨迹与地图标注的通用交换格式；KMZ 是它的 ZIP 封装。MoonBit 生态已有 shapefile、GeoJSON、WKT/WKB、GPX、TopoJSON、MVT 等 GIS 模块，KML/KMZ 此前一直是空缺。

## 安装

```bash
moon add cp15695540483/moonkml
```

在 `moon.pkg` 中导入：

```
import {
  "cp15695540483/moonkml" @kml,
}
```

## 能力

| 能力 | 状态 |
| --- | --- |
| KML 解析（XML 子集：元素、属性、文本、CDATA、注释、PI、实体引用） | ✅ |
| 几何：Point / LineString / Polygon（外环 + 内环）/ MultiGeometry / gx:Track | ✅ |
| Placemark `name` / `description` / `styleUrl` / Folder 路径 / TimeStamp·TimeSpan | ✅ |
| Style（LineStyle / PolyStyle / IconStyle / LabelStyle）与 StyleMap | ✅ |
| ExtendedData（`Data name/value`） | ✅ |
| KML 序列化（模型 → KML 文本） | ✅ |
| KMZ 读写（ZIP + DEFLATE + CRC32）；多条目/资源提取 | ✅ |
| GeoJSON 导入与导出（RFC 7946）、GPX 1.1 导入与导出 | ✅ |
| 数据校验（坐标越界、环闭合、样式悬空、gx:Track 一致性） | ✅ |
| 命令行：摘要 / GeoJSON / GPX 输出 / 校验 | ✅ |
| Camera / LookAt / NetworkLink / 三维模型与叠置图层 | 未实现（明确不做，见覆盖矩阵） |

## 使用

### 解析 KML 文本

```moonbit
let doc = try! @kml.parse(kml_text)
println(doc.name)
for pm in doc.placemarks {
  match pm.geometry {
    Some(@kml.Geometry::Point(p)) => println(pm.name + ": " + p.lon.to_string() + ", " + p.lat.to_string())
    Some(@kml.Geometry::LineString(ls)) => println(pm.name + ": " + ls.point_count().to_string() + " vertices")
    Some(@kml.Geometry::Polygon(poly)) => println(pm.name + ": " + poly.inner_count().to_string() + " holes")
    Some(@kml.Geometry::MultiGeometry(gs)) => println(pm.name + ": " + gs.length().to_string() + " parts")
    Some(@kml.Geometry::GxTrack(t)) => println(pm.name + ": " + t.point_count().to_string() + " track points")
    None => println(pm.name + ": no geometry")
  }
}
```

### 读写 KMZ

```moonbit
let doc = try! @kml.kmz_parse(kmz_bytes)   // 支持 DEFLATE 压缩的标准 KMZ
let bytes = @kml.kmz_pack(doc)             // 打包为 KMZ
```

### 导出

四种格式两两互通（KML、KMZ、GeoJSON、GPX）：

```moonbit
let kml_text = @kml.serialize(doc)   // KML
let kmz = @kml.kmz_pack(doc)         // KMZ
let geojson = @kml.to_geojson(doc)   // GeoJSON
let gpx = @kml.to_gpx(doc)           // GPX

let doc2 = try! @kml.from_geojson(geojson_text)
let doc3 = try! @kml.from_gpx(gpx_text)
let doc4 = try! @kml.kmz_parse(kmz_bytes)
```

### 命令行

```bash
# 输入可以是 .kml / .kmz / .geojson / .gpx
moon run cmd/main -- examples/sample.kml --summary
moon run cmd/main -- examples/oracle.kmz --kml
moon run cmd/main -- examples/sample.gpx --geojson
moon run cmd/main -- examples/sample.geojson --gpx
moon run cmd/main -- examples/negative/broken.kml --validate   # 退出码 1
```

## API 摘要

- `parse(text : String) -> KmlDocument raise KmlError`
- `serialize(doc : KmlDocument) -> String`
- `kmz_parse(data : Bytes) -> KmlDocument` / `kmz_pack(doc) -> Bytes` / `kmz_pack_with(doc, extra)`
- `kmz_entry_names(data) -> Array[String]` / `kmz_extract(data, name) -> Bytes?`
- `to_geojson(doc) -> String` / `from_geojson(text) -> KmlDocument`
- `to_gpx(doc) -> String` / `from_gpx(text) -> KmlDocument`
- `validate(doc) -> Array[ValidationIssue]`：文档质检
- `parse_xml(text) -> XmlElement raise KmlError`（通用 XML 子集）
- `KmlDocument::{ name, placemarks, styles, style_maps, placemark_count(), style_count(), style_map_count(), find_style(id), find_style_map(id) }`
- `Placemark::{ name, description, geometry, style_url, extended_data, folder, timestamp, has_geometry(), has_point(), has_line_string(), has_multi_geometry(), has_gx_track(), has_time(), data_count(), find_data(name) }`
- `Placemark::new(name, geometry)`：便捷构造
- `Geometry::{ Point(KmlPoint), LineString(KmlLineString), Polygon(KmlPolygon), MultiGeometry(Array[Geometry]), GxTrack(KmlGxTrack) }`
- `KmlPolygon::{ outer, inner, inner_count() }`、`KmlStyle::{ id, line_color, line_width, fill_color }`

## 读写不变式

这几条是库对外承诺的，测试逐条覆盖：

- **往返守恒**：`parse(serialize(doc))` 后 placemarks / styles / style_maps 数量与几何种类不变；`tools/roundtrip_check.py` 在 CI 里盯这条。
- **坐标不被改写**：序列化用最短可往返的 Double 表示，不截断精度；`116.3975` 进出仍是 `116.3975`。
- **未知元素不致命**：KML 允许厂商扩展，遇到未建模元素忽略而非报错，但**不静默改写**已识别数据。
- **坏数据不被伪装成好数据**：解析宽松（真实数据常有未闭合环），`validate` 报告问题且 CLI 退出码为 1。

## KML / KMZ 的五个坑

这些是照规范实现时真正卡住过的地方，也是本库与「能解析 XML」之间的差别：

1. **真实 KMZ 几乎都是 DEFLATE**。只实现 Stored 时，对 simplekml 生成的 394 字节 KMZ 直接报 `unsupported zip compression`；补上 inflate 后同一文件解出 2 个 Placemark。规范说 doc.kml 应在 ZIP 根，但够宽松的读取器要能在缺失时回退到首个 `.kml`。
2. **`<coordinates>` 与 `<gx:coord>` 是两套语法**。前者把 `lon,lat[,alt]` 用空白分隔成元组，后者直接把 `lon lat alt` 用空格分开；共用解析器会在 `gx:Track` 上解析失败。
3. **`<LinearRing>` 要求首尾点闭合、至少 4 点**，但真实数据经常不闭合，Google Earth 照样渲染。所以解析不能拒绝，`validate` 必须报告——「宽松解析 + 严格校验」是两件事。
4. **KML 颜色是 `aabbggrr`**：alpha 在最前，蓝绿红倒序，与 CSS 的 `#rrggbbaa` 正好相反。本库只做原样保留、不做 RGBA 转换，因为任何自动转换都会在 alpha 语义上引入错误解释。
5. **`<Folder>` 的层级在拍平后不可恢复**。文件里 Placemark 是深度优先顺序，丢了层级就无法还原目录树；因此每个 Placemark 记录 `folder = "A/B"` 路径。

## 验证

本地三关（CI 逐步执行同样的命令）：

```bash
moon fmt --check
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc && moon test --target js && moon test --target native
```

领域门禁（普通 MoonBit 项目不需要，这里是必需的）：

```bash
python tools/roundtrip_check.py   # 双后端输出逐字节一致 + 往返守恒
python tools/gen_oracle.py        # 用 simplekml 生成独立实现产物
```

CI 在 wasm-gc / js / native 三后端各跑 74 个用例，然后做跨后端一致性、与 simplekml 对拍、坏数据断言与导出产物形状检查。跨后端一致性是重点：坐标是 Double，wasm-gc 与 js 的格式化并非同一份实现，只跑一个后端会漏掉 `116.39750000000001` 这类偏差。

## 性能

```moon bench benchmarks --target wasm-gc --release```（本机 Windows）：

| 用例 | 平均耗时 |
| --- | --- |
| 解析 1000 个点 Placemark | 5.15 ms |
| 序列化 1000 个点 Placemark | 1.24 ms |
| KMZ 打包（200 点） | 2.28 ms |
| KMZ 解包（200 点） | 1.04 ms |

## 演示视频

[docs/demo.mp4](docs/demo.mp4)（23 秒）：真实执行 CLI、bench 与 test，依次展示读真实 KMZ、导入 GPX、导出 GeoJSON、校验正常与坏数据、解析 1000 点耗时、测试全绿。

视频由 `tools/record_demo.py` 生成（真实执行命令、捕获输出、渲染终端画面、ffmpeg 编码），可重复录制：

```bash
python tools/record_demo.py --ffmpeg <ffmpeg 路径>
```

## 覆盖范围

元素级支持矩阵见 [docs/KML-COVERAGE.md](docs/KML-COVERAGE.md)，含「明确不做」的部分（Camera / NetworkLink / GroundOverlay / Model / 渲染语义 / gx:Tour）。

## 许可与依据

Apache-2.0，见 [LICENSE](LICENSE)。

规范依据：OGC KML 2.2、RFC 7946（GeoJSON）、GPX 1.1 Schema、RFC 1951（DEFLATE）。

依赖：`moonbit-community/flate` 0.10.0（DEFLATE 解压，Apache-2.0）与 `moonbitlang/x` 0.5.7（文件 I/O，Apache-2.0）。

对拍素材 `examples/oracle.kml` / `oracle.kmz` 由 simplekml 1.3.2 在本地生成（`tools/gen_oracle.py` 可复现），仅作测试输入，源码未并入、未链接。
