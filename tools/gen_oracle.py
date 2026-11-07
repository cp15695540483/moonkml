import sys
sys.stdout.reconfigure(encoding="utf-8")
import simplekml

kml = simplekml.Kml(name="OracleDoc")
p = kml.newpoint(name="P1", coords=[(116.3975, 39.9087, 44)])
p.description = "capital"
ls = kml.newlinestring(name="L1", coords=[(0, 0), (1, 1), (2, 2)])
kml.save(r"C:/Users/1510/Desktop/moon/moonkml/examples/oracle.kml")
kml.savekmz(r"C:/Users/1510/Desktop/moon/moonkml/examples/oracle.kmz")
print("saved")
