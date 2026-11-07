"""用 simplekml 生成独立实现的 KML/KMZ，供互操作对拍使用。"""
import sys
sys.stdout.reconfigure(encoding="utf-8")
import os
import simplekml

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "examples")
os.makedirs(OUT, exist_ok=True)

kml = simplekml.Kml(name="OracleDoc")
p = kml.newpoint(name="P1", coords=[(116.3975, 39.9087, 44)])
p.description = "capital"
kml.newlinestring(name="L1", coords=[(0, 0), (1, 1), (2, 2)])
kml.save(os.path.join(OUT, "oracle.kml"))
kml.savekmz(os.path.join(OUT, "oracle.kmz"))
print("saved oracle.kml / oracle.kmz")
