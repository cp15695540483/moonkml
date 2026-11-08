// CLI：解析 KML/KMZ 文件并输出多种格式。
// 用法：moon run cmd/main -- <input.kml|.kmz> [--geojson|--gpx|--summary]

///|
fn usage() -> Unit {
  println(
    "usage: moonkml <input.kml|.kmz|.geojson|.gpx> [--summary|--geojson|--gpx|--validate]",
  )
}

///|
fn read_text(path : String) -> String raise @kml.KmlError {
  @fs.read_file_to_string(path) catch {
    @fs.IOError::IOError(msg) => raise @kml.KmlError::HostIo(msg)
  }
}

///|
fn read_bytes(path : String) -> Bytes raise @kml.KmlError {
  @fs.read_file_to_bytes(path) catch {
    @fs.IOError::IOError(msg) => raise @kml.KmlError::HostIo(msg)
  }
}

///|
fn run_cli(args : Array[String]) -> Int32 {
  let mut base = 1
  if base < args.length() && args[base].has_suffix(".js") {
    base = base + 1
  }
  if base >= args.length() {
    usage()
    return 2
  }
  let path = args[base]
  let mode = if base + 1 < args.length() { args[base + 1] } else { "--summary" }
  try {
    let doc = if path.has_suffix(".kmz") {
      @kml.kmz_parse(read_bytes(path))
    } else if path.has_suffix(".geojson") || path.has_suffix(".json") {
      @kml.from_geojson(read_text(path))
    } else if path.has_suffix(".gpx") {
      @kml.from_gpx(read_text(path))
    } else {
      @kml.parse(read_text(path))
    }
    if mode == "--validate" {
      let issues = @kml.validate(doc)
      if issues.length() == 0 {
        println("OK\tno issues")
      } else {
        for issue in issues {
          println("ISSUE\t" + issue.placemark + "\t" + issue.message)
        }
      }
      return if issues.length() == 0 { 0 } else { 1 }
    }
    if mode == "--kml" {
      println(@kml.serialize(doc))
      return 0
    }
    if mode == "--geojson" {
      println(@kml.to_geojson(doc))
    } else if mode == "--gpx" {
      println(@kml.to_gpx(doc))
    } else {
      println("document: " + doc.name)
      println("placemarks: " + doc.placemark_count().to_string())
      println("styles: " + doc.style_count().to_string())
      for pm in doc.placemarks {
        match pm.geometry {
          Some(@kml.Geometry::Point(p)) =>
            println(
              pm.name +
              " -> point " +
              p.lon.to_string() +
              ", " +
              p.lat.to_string(),
            )
          Some(@kml.Geometry::LineString(ls)) =>
            println(
              pm.name + " -> line " + ls.point_count().to_string() + " vertices",
            )
          Some(@kml.Geometry::Polygon(poly)) =>
            println(
              pm.name +
              " -> polygon " +
              poly.inner_count().to_string() +
              " holes",
            )
          Some(@kml.Geometry::MultiGeometry(geoms)) =>
            println(
              pm.name + " -> multi " + geoms.length().to_string() + " parts",
            )
          Some(@kml.Geometry::GxTrack(track)) =>
            println(
              pm.name +
              " -> gx:Track " +
              track.point_count().to_string() +
              " points",
            )
          None => println(pm.name + " -> (no geometry)")
        }
      }
    }
    return 0
  } catch {
    @kml.KmlError::XmlSyntax(msg, at) => {
      println("ERROR\txml: " + msg + " at " + at.to_string())
      return 1
    }
    @kml.KmlError::BadCoordinates(msg) => {
      println("ERROR\tcoords: " + msg)
      return 1
    }
    @kml.KmlError::HostIo(msg) => {
      println("ERROR\tio: " + msg)
      return 1
    }
    _ => {
      println("ERROR\tparse failed")
      return 1
    }
  }
}

///|
fn main {
  let code = run_cli(@env.args())
  if code != 0 {
    @sys.exit(code)
  }
}
