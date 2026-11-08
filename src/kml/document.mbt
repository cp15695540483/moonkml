// KML 文档解析：样式、扩展数据、时间、Placemark 与整体遍历。

///|
priv struct Collector {
  mut document_name : String
  placemarks : Array[@core.Placemark]
  styles : Array[@core.KmlStyle]
  style_maps : Array[@core.KmlStyleMap]
}

///|
fn parse_color(text : String) -> String? {
  let trimmed = @core.trim_text(text)
  let data = @utf8.encode(trimmed)
  if data.length() != 8 {
    return None
  }
  let mut i = 0
  while i < 8 {
    let d = @core.hex_digit(data[i])
    if d < 0 {
      return None
    }
    i = i + 1
  }
  Some(trimmed)
}

///|
fn parse_style(elem : @core.XmlElement) -> @core.KmlStyle {
  let id = match @core.first_element(elem, "id") {
    Some(_) => "x"
    None => ""
  }
  // 实际 id 是元素属性，不是子元素
  let real_id = match elem.attr("id") {
    Some(v) => v
    None => id
  }
  let mut line_color : String? = None
  let mut line_width : Double? = None
  let mut fill_color : String? = None
  let mut icon_href : String? = None
  let mut icon_scale : Double? = None
  let mut label_color : String? = None
  let mut label_scale : Double? = None
  match @core.first_element(elem, "LineStyle") {
    Some(ls) => {
      match @core.first_element(ls, "color") {
        Some(c) => line_color = parse_color(c.text())
        None => ()
      }
      match @core.first_element(ls, "width") {
        Some(w) => line_width = @core.parse_double(@core.trim_text(w.text()))
        None => ()
      }
    }
    None => ()
  }
  match @core.first_element(elem, "PolyStyle") {
    Some(ps) =>
      match @core.first_element(ps, "color") {
        Some(c) => fill_color = parse_color(c.text())
        None => ()
      }
    None => ()
  }
  match @core.first_element(elem, "IconStyle") {
    Some(icon) => {
      match @core.first_element(icon, "Icon") {
        Some(icon_el) =>
          match @core.first_element(icon_el, "href") {
            Some(h) => icon_href = Some(@core.trim_text(h.text()))
            None => ()
          }
        None => ()
      }
      match @core.first_element(icon, "scale") {
        Some(s) => icon_scale = @core.parse_double(@core.trim_text(s.text()))
        None => ()
      }
    }
    None => ()
  }
  match @core.first_element(elem, "LabelStyle") {
    Some(label) => {
      match @core.first_element(label, "color") {
        Some(c) => label_color = parse_color(c.text())
        None => ()
      }
      match @core.first_element(label, "scale") {
        Some(s) => label_scale = @core.parse_double(@core.trim_text(s.text()))
        None => ()
      }
    }
    None => ()
  }
  {
    id: real_id,
    line_color,
    line_width,
    fill_color,
    icon_href,
    icon_scale,
    label_color,
    label_scale,
  }
}

///|
fn parse_style_map(elem : @core.XmlElement) -> @core.KmlStyleMap {
  let id = match elem.attr("id") {
    Some(v) => v
    None => ""
  }
  let mut normal = ""
  let mut highlight = ""
  let mut i = 0
  while i < elem.children.length() {
    match elem.children[i] {
      Element(pair) =>
        if pair.name == "Pair" {
          let key = match @core.first_element(pair, "key") {
            Some(k) => @core.trim_text(k.text())
            None => ""
          }
          let url = match @core.first_element(pair, "styleUrl") {
            Some(u) => @core.trim_text(u.text())
            None => ""
          }
          if key == "normal" {
            normal = url
          } else if key == "highlight" {
            highlight = url
          }
        }
      Text(_) => ()
    }
    i = i + 1
  }
  { id, normal, highlight, }
}

///|
fn parse_extended_data(elem : @core.XmlElement) -> Array[@core.KmlData] {
  let out : Array[@core.KmlData] = []
  match @core.first_element(elem, "ExtendedData") {
    None => ()
    Some(ext) => {
      let mut i = 0
      while i < ext.children.length() {
        match ext.children[i] {
          Element(data_elem) =>
            if data_elem.name == "Data" {
              let name = match data_elem.attr("name") {
                Some(v) => v
                None => ""
              }
              let value = match @core.first_element(data_elem, "value") {
                Some(v) => @core.trim_text(v.text())
                None => ""
              }
              out.push({ name, value, })
            }
          Text(_) => ()
        }
        i = i + 1
      }
    }
  }
  out
}

///|
fn parse_time(elem : @core.XmlElement) -> @core.KmlTime? {
  match @core.first_element(elem, "TimeStamp") {
    Some(ts) =>
      match @core.first_element(ts, "when") {
        Some(w) =>
          Some({ when: @core.trim_text(w.text()), begin: "", end: "", })
        None => None
      }
    None =>
      match @core.first_element(elem, "TimeSpan") {
        Some(span) => {
          let begin = match @core.first_element(span, "begin") {
            Some(b) => @core.trim_text(b.text())
            None => ""
          }
          let end = match @core.first_element(span, "end") {
            Some(e) => @core.trim_text(e.text())
            None => ""
          }
          Some({ when: "", begin, end, })
        }
        None => None
      }
  }
}

///|
fn parse_placemark(
  elem : @core.XmlElement,
  folder : String,
) -> @core.Placemark raise @core.KmlError {
  let name = match @core.child_text(elem, "name") {
    Some(t) => t
    None => ""
  }
  let description = match @core.child_text(elem, "description") {
    Some(t) => t
    None => ""
  }
  let geometry : @core.Geometry? = match parse_point(elem) {
    Some(p) => Some(@core.Geometry::Point(p))
    None =>
      match parse_line_string(elem) {
        Some(ls) => Some(@core.Geometry::LineString(ls))
        None =>
          match parse_polygon(elem) {
            Some(poly) => Some(@core.Geometry::Polygon(poly))
            None =>
              match parse_gx_track(elem) {
                Some(track) => Some(@core.Geometry::GxTrack(track))
                None =>
                  match parse_multi_geometry(elem) {
                    Some(geoms) => Some(@core.Geometry::MultiGeometry(geoms))
                    None => None
                  }
              }
          }
      }
  }
  let style_url = match @core.child_text(elem, "styleUrl") {
    Some(t) => t
    None => ""
  }
  let extended_data = parse_extended_data(elem)
  let timestamp = parse_time(elem)
  { name, description, geometry, style_url, extended_data, folder, timestamp, }
}

///|
fn walk(
  elem : @core.XmlElement,
  acc : Collector,
  folder : String,
) -> Unit raise @core.KmlError {
  if elem.name == "Document" && acc.document_name == "" {
    match @core.child_text(elem, "name") {
      Some(t) => acc.document_name = t
      None => ()
    }
  }
  if elem.name == "Placemark" {
    acc.placemarks.push(parse_placemark(elem, folder))
  }
  if elem.name == "Style" {
    acc.styles.push(parse_style(elem))
  }
  if elem.name == "StyleMap" {
    acc.style_maps.push(parse_style_map(elem))
  }
  let mut i = 0
  while i < elem.children.length() {
    match elem.children[i] {
      Element(child) => {
        let child_folder = if child.name == "Folder" {
          let fname = match @core.child_text(child, "name") {
            Some(t) => t
            None => ""
          }
          if folder == "" {
            fname
          } else if fname == "" {
            folder
          } else {
            folder + "/" + fname
          }
        } else {
          folder
        }
        walk(child, acc, child_folder)
      }
      Text(_) => ()
    }
    i = i + 1
  }
}

///|
pub fn parse(text : String) -> @core.KmlDocument raise @core.KmlError {
  let root = @core.parse_xml(text)
  let acc : Collector = {
    document_name: "",
    placemarks: [],
    styles: [],
    style_maps: [],
  }
  walk(root, acc, "")
  {
    name: acc.document_name,
    placemarks: acc.placemarks,
    styles: acc.styles,
    style_maps: acc.style_maps,
  }
}
