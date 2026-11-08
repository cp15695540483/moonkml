// 门面包：把各子包的公开符号重导出，调用方仍用 @kml.xxx。
//
// 分层：core 底座（模型/XML/文本/数值/字节输出）→ kml 读写 → formats 互转 / kmz 容器 / check 校验。

///|
pub using @core {
  type KmlError,
  type KmlPoint,
  type KmlLineString,
  type LinearRing,
  type KmlPolygon,
  type KmlGxTrack,
  type Geometry,
  type KmlDocument,
  type KmlStyle,
  type KmlStyleMap,
  type KmlData,
  type KmlTime,
  type Placemark,
  type XmlAttr,
  type XmlNode,
  type XmlElement,
  parse_xml,
  first_element,
  child_text,
  trim_text,
  split_commas,
  split_whitespace,
  parse_double,
  hex_digit,
  dec_digit,
  is_space,
  push_lit,
  push_escaped,
  push_newline,
  push_double,
}

///|
pub using @kml {parse, serialize}

///|
pub using @formats {to_geojson, from_geojson, to_gpx, from_gpx}

///|
pub using @kmz {
  type ZipEntry,
  zip_pack,
  zip_find,
  kmz_pack,
  kmz_pack_with,
  kmz_parse,
  kmz_entry_names,
  kmz_extract,
}

///|
pub using @check {type ValidationIssue, validate}
