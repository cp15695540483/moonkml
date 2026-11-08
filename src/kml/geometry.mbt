// KML 几何解析：坐标文本到 Point / LineString / Polygon / MultiGeometry / gx:Track。

///|
fn parse_coordinate(text : String) -> @core.KmlPoint raise @core.KmlError {
  let parts = @core.split_commas(text)
  if parts.length() < 2 || parts[0] == "" || parts[1] == "" {
    raise BadCoordinates(text)
  }
  let lon = @core.parse_double(parts[0])
  let lat = @core.parse_double(parts[1])
  let alt = if parts.length() >= 3 && parts[2] != "" {
    @core.parse_double(parts[2])
  } else {
    None
  }
  match (lon, lat) {
    (Some(lon), Some(lat)) => { lon, lat, alt, }
    _ => raise BadCoordinates(text)
  }
}

///|
fn parse_point(elem : @core.XmlElement) -> @core.KmlPoint? raise @core.KmlError {
  match @core.first_element(elem, "Point") {
    None => None
    Some(point_elem) =>
      match @core.first_element(point_elem, "coordinates") {
        None => raise MissingCoordinates
        Some(coords) => Some(parse_coordinate(@core.trim_text(coords.text())))
      }
  }
}

///|
fn parse_line_string(
  elem : @core.XmlElement,
) -> @core.KmlLineString? raise @core.KmlError {
  match @core.first_element(elem, "LineString") {
    None => None
    Some(ls_elem) =>
      match @core.first_element(ls_elem, "coordinates") {
        None => raise MissingCoordinates
        Some(coords) => {
          let text = @core.trim_text(coords.text())
          let tuples = @core.split_whitespace(text)
          let points : Array[@core.KmlPoint] = []
          let mut i = 0
          while i < tuples.length() {
            if tuples[i] != "" {
              points.push(parse_coordinate(tuples[i]))
            }
            i = i + 1
          }
          if points.length() == 0 {
            raise BadCoordinates(text)
          }
          Some({ points, })
        }
      }
  }
}

///|
fn parse_ring(elem : @core.XmlElement) -> @core.LinearRing raise @core.KmlError {
  match @core.first_element(elem, "coordinates") {
    None => raise MissingCoordinates
    Some(coords) => {
      let text = @core.trim_text(coords.text())
      let tuples = @core.split_whitespace(text)
      let points : Array[@core.KmlPoint] = []
      let mut i = 0
      while i < tuples.length() {
        if tuples[i] != "" {
          points.push(parse_coordinate(tuples[i]))
        }
        i = i + 1
      }
      if points.length() < 3 {
        raise BadCoordinates(text)
      }
      let ring : @core.LinearRing = { points, }
      ring
    }
  }
}

///|
fn parse_polygon_container(
  elem : @core.XmlElement,
) -> @core.KmlPolygon? raise @core.KmlError {
  match @core.first_element(elem, "outerBoundaryIs") {
    None => raise BadCoordinates("missing outerBoundaryIs")
    Some(outer_boundary) =>
      match @core.first_element(outer_boundary, "LinearRing") {
        None => raise BadCoordinates("missing outer LinearRing")
        Some(outer_ring) => {
          let inner : Array[@core.LinearRing] = []
          let mut i = 0
          while i < elem.children.length() {
            match elem.children[i] {
              Element(inner_boundary) =>
                if inner_boundary.name == "innerBoundaryIs" {
                  match @core.first_element(inner_boundary, "LinearRing") {
                    Some(ring_elem) => inner.push(parse_ring(ring_elem))
                    None =>
                      raise BadCoordinates("innerBoundaryIs missing LinearRing")
                  }
                }
              Text(_) => ()
            }
            i = i + 1
          }
          Some({ outer: parse_ring(outer_ring), inner, })
        }
      }
  }
}

///|
fn parse_polygon(
  elem : @core.XmlElement,
) -> @core.KmlPolygon? raise @core.KmlError {
  match @core.first_element(elem, "Polygon") {
    None => None
    Some(poly) =>
      match @core.first_element(poly, "outerBoundaryIs") {
        None => raise BadCoordinates("missing outerBoundaryIs")
        Some(outer_boundary) =>
          match @core.first_element(outer_boundary, "LinearRing") {
            None => raise BadCoordinates("missing outer LinearRing")
            Some(outer_ring) => {
              let inner : Array[@core.LinearRing] = []
              let mut i = 0
              while i < poly.children.length() {
                match poly.children[i] {
                  Element(inner_boundary) =>
                    if inner_boundary.name == "innerBoundaryIs" {
                      match @core.first_element(inner_boundary, "LinearRing") {
                        Some(ring_elem) => inner.push(parse_ring(ring_elem))
                        None =>
                          raise BadCoordinates(
                            "innerBoundaryIs missing LinearRing",
                          )
                      }
                    }
                  Text(_) => ()
                }
                i = i + 1
              }
              Some({ outer: parse_ring(outer_ring), inner, })
            }
          }
      }
  }
}

///|
fn parse_gx_track(
  elem : @core.XmlElement,
) -> @core.KmlGxTrack? raise @core.KmlError {
  match @core.first_element(elem, "gx:Track") {
    None => None
    Some(track) => {
      let whens : Array[String] = []
      let coords : Array[@core.KmlPoint] = []
      let mut i = 0
      while i < track.children.length() {
        match track.children[i] {
          Element(child) =>
            if child.name == "when" {
              whens.push(@core.trim_text(child.text()))
            } else if child.name == "gx:coord" {
              let parts = @core.split_whitespace(@core.trim_text(child.text()))
              if parts.length() < 2 {
                raise BadCoordinates(@core.trim_text(child.text()))
              }
              let lon = @core.parse_double(parts[0])
              let lat = @core.parse_double(parts[1])
              let alt = if parts.length() >= 3 && parts[2] != "" {
                @core.parse_double(parts[2])
              } else {
                None
              }
              match (lon, lat) {
                (Some(lon), Some(lat)) => coords.push({ lon, lat, alt, })
                _ => raise BadCoordinates(@core.trim_text(child.text()))
              }
            }
          Text(_) => ()
        }
        i = i + 1
      }
      Some({ whens, coords, })
    }
  }
}

///|
fn parse_multi_geometry(
  elem : @core.XmlElement,
) -> Array[@core.Geometry]? raise @core.KmlError {
  match @core.first_element(elem, "MultiGeometry") {
    None => None
    Some(multi) => {
      let geoms : Array[@core.Geometry] = []
      let mut i = 0
      while i < multi.children.length() {
        match multi.children[i] {
          Element(child) =>
            match geometry_from_elem(child) {
              Some(g) => geoms.push(g)
              None => ()
            }
          Text(_) => ()
        }
        i = i + 1
      }
      Some(geoms)
    }
  }
}

///|
fn geometry_from_elem(
  elem : @core.XmlElement,
) -> @core.Geometry? raise @core.KmlError {
  if elem.name == "Point" {
    match @core.first_element(elem, "coordinates") {
      None => raise MissingCoordinates
      Some(coords) =>
        Some(
          @core.Geometry::Point(
            parse_coordinate(@core.trim_text(coords.text())),
          ),
        )
    }
  } else if elem.name == "LineString" {
    match @core.first_element(elem, "coordinates") {
      None => raise MissingCoordinates
      Some(coords) => {
        let text = @core.trim_text(coords.text())
        let tuples = @core.split_whitespace(text)
        let points : Array[@core.KmlPoint] = []
        let mut i = 0
        while i < tuples.length() {
          if tuples[i] != "" {
            points.push(parse_coordinate(tuples[i]))
          }
          i = i + 1
        }
        if points.length() == 0 {
          raise BadCoordinates(text)
        }
        Some(@core.Geometry::LineString({ points, }))
      }
    }
  } else if elem.name == "Polygon" {
    match parse_polygon_container(elem) {
      Some(poly) => Some(@core.Geometry::Polygon(poly))
      None => None
    }
  } else if elem.name == "gx:Track" {
    let whens : Array[String] = []
    let coords : Array[@core.KmlPoint] = []
    let mut i = 0
    while i < elem.children.length() {
      match elem.children[i] {
        Element(child) =>
          if child.name == "when" {
            whens.push(@core.trim_text(child.text()))
          } else if child.name == "gx:coord" {
            let parts = @core.split_whitespace(@core.trim_text(child.text()))
            if parts.length() >= 2 {
              let lon = @core.parse_double(parts[0])
              let lat = @core.parse_double(parts[1])
              match (lon, lat) {
                (Some(lon), Some(lat)) => coords.push({ lon, lat, alt: None, })
                _ => ()
              }
            }
          }
        Text(_) => ()
      }
      i = i + 1
    }
    Some(@core.Geometry::GxTrack({ whens, coords, }))
  } else {
    None
  }
}
