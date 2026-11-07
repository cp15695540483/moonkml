# KML 2.2 覆盖矩阵

按 OGC KML 2.2 的主要元素列出支持状态。`✅` 表示解析+序列化，`读` 表示仅解析，
`—` 表示明确不实现（简化边界，非缺陷）。

## 文档与容器

| 元素 | 状态 | 说明 |
| --- | --- | --- |
| `<kml>` | ✅ | 根元素；命名空间属性被忽略 |
| `<Document>` | ✅ | 名称与 Placemark / Style / StyleMap 收集 |
| `<Folder>` | 读 | 记录每个 Placemark 的 Folder 路径（`folder` 字段），序列化时拍平 |
| `<name>` / `<description>` | ✅ | 支持实体与 CDATA |
| `<ExtendedData><Data>` | ✅ | `name` 属性 + `<value>` |
| `<ExtendedData><SchemaData>` | — | 不做类型化 Schema |

## 几何

| 元素 | 状态 | 说明 |
| --- | --- | --- |
| `<Point>` | ✅ | 含可选高度 |
| `<LineString>` | ✅ | 空白/换行分隔的多顶点 |
| `<LinearRing>` | ✅ | 外环与内环 |
| `<Polygon>` | ✅ | `outerBoundaryIs` + 多个 `innerBoundaryIs` |
| `<MultiGeometry>` | ✅ | 递归嵌套任意几何 |
| `<gx:Track>` | ✅ | `<when>` + `<gx:coord>`（空格分隔 lon lat alt） |
| `<Model>` / `<GroundOverlay>` / `<ScreenOverlay>` | — | 不在库范围 |
| `<altitudeMode>` / `<extrude>` / `<tessellate>` | — | 渲染语义；库只搬运坐标 |

## 样式

| 元素 | 状态 | 说明 |
| --- | --- | --- |
| `<Style id>` | ✅ | |
| `<LineStyle>` | ✅ | `<color>`（aabbggrr）与 `<width>` |
| `<PolyStyle>` | ✅ | `<color>` |
| `<IconStyle>` | ✅ | `<scale>` 与 `<Icon><href>` |
| `<LabelStyle>` | ✅ | `<color>` 与 `<scale>` |
| `<StyleMap>` | ✅ | `normal` / `highlight` 两个 Pair |
| `<styleUrl>` | ✅ | 保留原始引用；校验会报告悬空引用 |
| `<BalloonStyle>` / `<ListStyle>` | — | 不影响数据消费 |

## 时间

| 元素 | 状态 | 说明 |
| --- | --- | --- |
| `<TimeStamp><when>` | ✅ | 原样保留字符串 |
| `<TimeSpan><begin>/<end>` | ✅ | 原样保留 |
| `<gx:TimeStamp>` / `<gx:TimeSpan>` | 读 | 与标准元素同一处理路径 |

## KMZ

| 能力 | 状态 |
| --- | --- |
| 读取 DEFLATE / Stored 条目 | ✅ |
| `doc.kml` 定位（缺失时回退首个 `.kml`） | ✅ |
| 条目列举与资源提取 | ✅ |
| 打包（含附加资源） | ✅ |
| CRC-32 校验 | ✅ |

## 转换

| 方向 | 状态 |
| --- | --- |
| KML → GeoJSON（Point/LineString/Polygon/gx:Track） | ✅ |
| GeoJSON → KML（含 MultiPoint/MultiLineString/MultiPolygon） | ✅ |
| GPX → KML（wpt/rte/trk） | ✅ |
| KML → GPX（wpt/trk） | ✅ |
| KML → KML（序列化） | ✅ |
| KMZ → KML / KML → KMZ | ✅ |
