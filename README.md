# moonkml

纯 MoonBit 实现的 [KML 2.2](https://www.ogc.org/standards/kml) 读写库，不依赖任何 C 库或平台 API，可运行在 `wasm-gc`、`js` 与 `native` 后端。

KML 是 Google Earth、无人机航迹、GPS 轨迹与地图标注的通用交换格式；KMZ 是它的 ZIP 封装。MoonBit 生态已有 shapefile、GeoJSON、GPX、TopoJSON、MVT 等 GIS 模块，但 KML/KMZ 一直是空缺。

## 当前支持

| 能力 | 状态 |
| --- | --- |
| XML 解析（元素、属性、文本、CDATA、注释、处理指令、实体引用） | ✅ |
| `<Document>` 名称 | ✅ |
| `<Placemark>` 的 `name` / `description` | ✅ |
| `<Point>` 与 `<coordinates>`（含可选高度） | ✅ |
| 其它几何（LineString / Polygon / MultiGeometry） | 计划中 |
| 样式（Style / StyleMap） | 计划中 |
| KMZ 读写 | 计划中 |
| KML 序列化 | 计划中 |
| 与 GeoJSON / GPX 互转 | 计划中 |

## 使用

模块尚未发布到 mooncakes.io；本地开发时：

```bash
moon run cmd/main
```

在其它工程中使用（依赖本地路径或发布后的模块名）：

```moonbit
let doc = try! @kml.parse(kml_text)
println(doc.name)
for pm in doc.placemarks {
  match pm.point {
    Some(p) => println(pm.name + ": " + p.lon.to_string() + ", " + p.lat.to_string())
    None => println(pm.name + ": no point")
  }
}
```

## API

- `parse(text : String) -> KmlDocument raise KmlError`：解析 KML 文本
- `parse_xml(text : String) -> XmlElement raise KmlError`：通用 XML 子集解析
- `KmlDocument::{ name, placemarks, placemark_count() }`
- `Placemark::{ name, description, point, has_point() }`
- `KmlPoint::{ lon, lat, alt }`

## 设计说明

- **XML 子集**：KML 只需要元素、属性、文本、CDATA、注释、处理指令与常见实体；不实现 DTD 实体展开与命名空间解析，遇到未知元素直接忽略（KML 允许扩展元素）。
- **错误模型**：`KmlError` 区分 XML 结构错误（带字节偏移）与 KML 语义缺失（缺 `coordinates`、坐标非法），便于调用方给出可定位的报错。
- **坐标解析**：单次除法/乘法做十进制定标，避免逐位缩放带来的多次舍入；测试用 1e-9 容差断言。

## 构建与测试

```bash
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc
moon test --target js
moon run cmd/main
```

## 许可证

Apache-2.0，见 [LICENSE](LICENSE)。

## 参考

- OGC KML 2.2（标准文档）
- Google KML 参考
