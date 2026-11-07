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

```moonbit
let geojson = @kml.to_geojson(doc)
let gpx = @kml.to_gpx(doc)
let kml_text = @kml.serialize(doc)
```

### 命令行

```bash
moon run cmd/main -- examples/sample.kml --summary
moon run cmd/main -- examples/sample.kml --geojson
moon run cmd/main -- examples/sample.kml --gpx
moon run cmd/main -- examples/sample.kml --validate
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

## 设计说明

- **XML 子集**：KML 只需要元素、属性、文本、CDATA、注释、处理指令与常见实体引用；不实现 DTD 实体展开与命名空间解析，未知元素直接忽略（KML 允许扩展元素）。
- **错误模型**：`KmlError` 区分 XML 结构错误（带字节偏移）、KML 语义错误（缺 `coordinates`、坐标非法）与宿主 I/O 错误，便于调用方给出可定位的报错。
- **坐标解析**：单次除法/乘法做十进制定标，避免逐位缩放带来的多次舍入；测试用 1e-9 容差断言。
- **ZIP 策略**：读取支持 Stored 与 DEFLATE（DEFLATE 解压复用 `moonbit-community/flate`，纯 MoonBit）；写入使用 DEFLATE + CRC32。

## 性能

`moon bench benchmarks --target wasm-gc --release`（本机 Windows，wasm-gc release）：

| 用例 | 平均耗时 |
| --- | --- |
| 解析 1000 个点 Placemark | 5.15 ms |
| 序列化 1000 个点 Placemark | 1.24 ms |
| KMZ 打包（200 点） | 2.28 ms |
| KMZ 解包（200 点） | 1.04 ms |

## 覆盖范围

元素级的支持矩阵见 [docs/KML-COVERAGE.md](docs/KML-COVERAGE.md)。

## 构建与测试

```bash
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc
moon test --target js
moon fmt --check
```

## 许可证

Apache-2.0，见 [LICENSE](LICENSE)。

## 参考

- OGC KML 2.2 标准
- RFC 7946（GeoJSON）、GPX 1.1 Schema
- `moonbit-community/flate`（DEFLATE 引擎，Apache-2.0）
