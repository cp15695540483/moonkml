// KML/KMZ 读写过程中的结构化错误。
//
// 解析入口以 KmlError 失败，调用方可以据此区分「XML 结构损坏」与「KML 语义缺失」。

///|
pub(all) suberror KmlError {
  /// XML 语法错误：描述 + 字节偏移
  XmlSyntax(String, Int32)
  /// 结束标签与开始标签不匹配
  XmlMismatch(String, String, Int32)
  /// 多余的结束标签
  XmlUnexpectedEnd(String, Int32)
  /// 有开始标签但没有闭合
  XmlUnclosed(String, Int32)
  /// 根元素缺失
  XmlMissingRoot
  /// 出现第二个根元素
  XmlMultipleRoots(Int32)
  /// 缺少 <coordinates>
  MissingCoordinates
  /// 坐标文本无法解析
  BadCoordinates(String)
  /// GeoJSON 导入失败
  BadGeoJson(String)
  /// GPX 导入失败
  BadGpx(String)
  /// 宿主 I/O 失败（库本身不做 I/O，由调用方转换进来）
  HostIo(String)
}
