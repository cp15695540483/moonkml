// KMZ 读写：ZIP 容器 + doc.kml 封装。
//
// KMZ 是「含 doc.kml 的 ZIP」，可以带图片/模型等资源文件。这里实现所需的最小
// ZIP 子集：读取支持 Stored 与 DEFLATE（解压复用 moonbit-community/flate），
// 写入统一用 DEFLATE + CRC-32。

///|
/// ZIP 本地文件头固定长度（不含文件名与额外字段）。
const LOCAL_HEADER_SIZE : Int32 = 30

///|
/// 一个 ZIP 条目（名字、内容与 CRC）。
pub(all) struct ZipEntry {
  name : String
  data : Bytes
}

///|
/// 读取小端 u16。
fn read_u16(data : Bytes, at : Int32) -> Int32 raise @core.KmlError {
  if at + 2 > data.length() {
    raise XmlSyntax("truncated zip u16", at)
  }
  data[at].to_uint().reinterpret_as_int() |
  (data[at + 1].to_uint().reinterpret_as_int() << 8)
}

///|
/// 读取小端 u32。
fn read_u32(data : Bytes, at : Int32) -> Int32 raise @core.KmlError {
  if at + 4 > data.length() {
    raise XmlSyntax("truncated zip u32", at)
  }
  let b0 = data[at].to_uint().reinterpret_as_int()
  let b1 = data[at + 1].to_uint().reinterpret_as_int()
  let b2 = data[at + 2].to_uint().reinterpret_as_int()
  let b3 = data[at + 3].to_uint().reinterpret_as_int()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
/// 写入小端 u16。
fn put_u16(out : Array[Byte], value : Int32) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
/// 写入小端 u32。
fn put_u32(out : Array[Byte], value : UInt32) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
/// CRC-32（IEEE 802.3，初始 0xFFFFFFFF，结果取反）。
fn crc32(data : Bytes) -> UInt32 {
  let mut crc : UInt32 = 0xFFFFFFFF
  let mut i = 0
  while i < data.length() {
    let byte : UInt32 = data[i].to_uint()
    crc = crc ^ byte
    let mut k = 0
    while k < 8 {
      let lsb = (crc & 1) == 1
      crc = crc >> 1
      if lsb {
        crc = crc ^ 0xEDB88320
      }
      k = k + 1
    }
    i = i + 1
  }
  crc ^ 0xFFFFFFFF
}

///|
/// 追加 ASCII 字符串的字节。
fn push_ascii(out : Array[Byte], text : String) -> Unit {
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() {
    out.push(data[i])
    i = i + 1
  }
}

///|
/// 写一个本地文件头（Stored，version 20，DOS 时间固定）。
fn put_local_header(
  out : Array[Byte],
  name : String,
  size : Int32,
  comp_size : Int32,
  compression : Int32,
  crc : UInt32,
) -> Unit {
  put_u32(out, 0x04034b50)
  put_u16(out, 20)
  put_u16(out, 0)
  put_u16(out, compression)
  put_u16(out, 0)
  put_u16(out, 0)
  put_u32(out, crc)
  put_u32(out, comp_size.reinterpret_as_uint())
  put_u32(out, size.reinterpret_as_uint())
  put_u16(out, @utf8.encode(name).length())
  put_u16(out, 0)
  push_ascii(out, name)
}

///|
/// 打包若干条目成 ZIP 字节流。
pub fn zip_pack(entries : Array[ZipEntry]) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  while i < entries.length() {
    let name = entries[i].name
    let data = entries[i].data
    let crc = crc32(data)
    let size = data.length()
    let compressed = @flate.deflate_all(data)
    let comp_size = compressed.length()
    put_local_header(out, name, size, comp_size, 8, crc)
    let mut k = 0
    while k < compressed.length() {
      out.push(compressed[k])
      k = k + 1
    }
    i = i + 1
  }
  let mut i = 0
  while i < entries.length() {
    let name = entries[i].name
    let data = entries[i].data
    let crc = crc32(data)
    let size = data.length()
    let compressed = @flate.deflate_all(data)
    let comp_size = compressed.length()
    let name_len = @utf8.encode(name).length()
    put_u32(out, 0x02014b50)
    put_u16(out, 20)
    put_u16(out, 20)
    put_u16(out, 0)
    put_u16(out, 8)
    put_u16(out, 0)
    put_u16(out, 0)
    put_u32(out, crc)
    put_u32(out, comp_size.reinterpret_as_uint())
    put_u32(out, size.reinterpret_as_uint())
    put_u16(out, name_len)
    put_u16(out, 0)
    put_u16(out, 0)
    put_u16(out, 0)
    put_u16(out, 0)
    put_u32(out, 0)
    put_u32(out, 0)
    push_ascii(out, name)
    i = i + 1
  }
  put_u32(out, 0x06054b50)
  put_u16(out, 0)
  put_u16(out, 0)
  put_u16(out, entries.length())
  put_u16(out, entries.length())
  put_u32(out, 0)
  put_u32(out, 0)
  put_u16(out, 0)
  Bytes::from_array(out)
}

///|
/// 一条 ZIP 记录：名字与内容区间。
priv struct ZipRecord {
  name : String
  content_start : Int32
  comp_size : Int32
  compression : Int32
}

///|
/// 枚举 ZIP 里的所有条目（按本地文件头顺序）。
fn zip_records(data : Bytes) -> Array[ZipRecord] raise @core.KmlError {
  let n = data.length()
  let out : Array[ZipRecord] = []
  let mut at = 0
  while at + LOCAL_HEADER_SIZE <= n {
    let sig = read_u32(data, at)
    if sig != 0x04034b50 {
      break
    }
    let compression = read_u16(data, at + 8)
    let comp_size = read_u32(data, at + 18)
    let name_len = read_u16(data, at + 26)
    let extra_len = read_u16(data, at + 28)
    let name_start = at + LOCAL_HEADER_SIZE
    if name_start + name_len + extra_len > n {
      raise XmlSyntax("truncated zip local header", at)
    }
    let content_start = name_start + name_len + extra_len
    if content_start + comp_size > n {
      raise XmlSyntax("truncated zip content", at)
    }
    out.push({
      name: @utf8.decode_lossy(
        data.clamped_view(start=name_start, end=name_start + name_len),
      ),
      content_start,
      comp_size,
      compression,
    })
    at = content_start + comp_size
  }
  out
}

///|
/// 解出某条记录的内容（按需 inflate）。
fn zip_record_data(
  data : Bytes,
  record : ZipRecord,
) -> Bytes raise @core.KmlError {
  let raw = data.clamped_view(
    start=record.content_start,
    end=record.content_start + record.comp_size,
  )
  if record.compression == 0 {
    return Bytes::from_array(raw.to_array())
  }
  if record.compression == 8 {
    return @flate.inflate_all(raw) catch {
      _ => raise XmlSyntax("inflate failed", record.content_start)
    }
  }
  raise XmlSyntax("unsupported zip compression", record.content_start)
}

///|
/// 列出 KMZ/ZIP 里的全部条目名。
pub fn kmz_entry_names(data : Bytes) -> Array[String] raise @core.KmlError {
  let records = zip_records(data)
  let out : Array[String] = []
  let mut i = 0
  while i < records.length() {
    out.push(records[i].name)
    i = i + 1
  }
  out
}

///|
/// 取出 KMZ/ZIP 里指定条目的内容。
pub fn kmz_extract(data : Bytes, name : String) -> Bytes? raise @core.KmlError {
  let records = zip_records(data)
  let mut i = 0
  while i < records.length() {
    if records[i].name == name {
      return Some(zip_record_data(data, records[i]))
    }
    i = i + 1
  }
  None
}

///|
/// 从 ZIP 里找第一个指定名字的条目内容。
pub fn zip_find(data : Bytes, name : String) -> Bytes? raise @core.KmlError {
  kmz_extract(data, name)
}

///|
/// 把 KML 文档与附加资源打包成 KMZ。
pub fn kmz_pack_with(doc : @core.KmlDocument, extra : Array[ZipEntry]) -> Bytes {
  let entries : Array[ZipEntry] = [
    { name: "doc.kml", data: @utf8.encode(@kml.serialize(doc)), },
  ]
  let mut i = 0
  while i < extra.length() {
    entries.push(extra[i])
    i = i + 1
  }
  zip_pack(entries)
}

///|
/// 把 KML 文档打包成 KMZ（仅含 doc.kml）。
pub fn kmz_pack(doc : @core.KmlDocument) -> Bytes {
  kmz_pack_with(doc, [])
}

///|
/// 从 KMZ 字节解出 KML 文档：优先 doc.kml，缺失时取第一个 .kml 条目。
pub fn kmz_parse(data : Bytes) -> @core.KmlDocument raise @core.KmlError {
  match kmz_extract(data, "doc.kml") {
    Some(kml) => @kml.parse(@utf8.decode_lossy(kml))
    None => {
      let names = kmz_entry_names(data)
      let mut i = 0
      while i < names.length() {
        if names[i].has_suffix(".kml") {
          match kmz_extract(data, names[i]) {
            Some(kml) => return @kml.parse(@utf8.decode_lossy(kml))
            None => ()
          }
        }
        i = i + 1
      }
      raise BadCoordinates("missing doc.kml")
    }
  }
}
