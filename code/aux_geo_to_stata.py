"""
aux_geo_to_stata.py  -  converte geometrie GeoJSON / WKT nel formato
coordinate usato da Stata (come i file *_shp.dta di spshape2dta):
ogni anello inizia con una riga con coordinate mancanti.

Solo libreria standard. Uso (dalla cartella del progetto):
    python code/aux_geo_to_stata.py

Input  (data/geo, data/work):
    zone_omi_2025_2.geojson      zone OMI 2025 (2 sem.), WGS84
    _expl_f205_2011_1.geojson    zone OMI 2011 (1 sem.), WGS84
    nil_geometry_wkt.csv         NIL (88) in WKT, esportato dal modulo 05
    nil_vigenti_ds964.geojson    NIL vigenti (Milano 2030), geografia del DS205
    nil_vecchi.geojson           NIL PGT 2012, geografia del file dell'indice
Output (data/geo):
    <nome>_coords.csv   _ID,_X,_Y          (anelli separati da riga vuota)
    <nome>_attr.csv     _ID,code[,descr]
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEO = os.path.join(ROOT, "data", "geo")
WORK = os.path.join(ROOT, "data", "work")


def geojson_rings(geom):
    """Restituisce la lista degli anelli (liste di (x, y)) di un Polygon/MultiPolygon."""
    if geom["type"] == "Polygon":
        polys = [geom["coordinates"]]
    elif geom["type"] == "MultiPolygon":
        polys = geom["coordinates"]
    else:
        raise ValueError("geometria non supportata: " + geom["type"])
    return [[(p[0], p[1]) for p in ring] for poly in polys for ring in poly]


def wkt_rings(wkt):
    """Ogni gruppo di parentesi piu' interno e' un anello (POLYGON o MULTIPOLYGON)."""
    rings = []
    for grp in re.findall(r"\(([^()]+)\)", wkt):
        pts = []
        for pair in grp.split(","):
            v = pair.split()
            pts.append((float(v[0]), float(v[1])))
        rings.append(pts)
    return rings


def write(name, shapes):
    """shapes: lista di (code, descr, rings)."""
    with open(os.path.join(GEO, name + "_coords.csv"), "w", newline="", encoding="utf-8") as fc, \
         open(os.path.join(GEO, name + "_attr.csv"), "w", newline="", encoding="utf-8") as fa:
        wc = csv.writer(fc)
        wa = csv.writer(fa)
        wc.writerow(["_ID", "_X", "_Y"])
        wa.writerow(["_ID", "code", "descr"])
        for i, (code, descr, rings) in enumerate(shapes, start=1):
            wa.writerow([i, code, descr])
            for ring in rings:
                wc.writerow([i, "", ""])
                for x, y in ring:
                    wc.writerow([i, repr(x), repr(y)])
    nr = sum(len(r) for _, _, r in shapes)
    print(f"  {name}: {len(shapes)} poligoni, {nr} anelli")


def omi(fname, name):
    path = os.path.join(GEO, fname)
    if not os.path.exists(path):
        print(f"  (manca {fname}: saltato)")
        return
    d = json.load(open(path, encoding="utf-8"))
    shapes = []
    for ft in d["features"]:
        p = ft["properties"]
        descr = (p.get("Zona_Descr") or "").strip().strip("'").strip()
        shapes.append((p["Zona"].strip().upper(), descr, geojson_rings(ft["geometry"])))
    write(name, shapes)


def nil_geojson(fname, name):
    """NIL da GeoJSON (campi ID_NIL e NIL), coordinate WGS84."""
    path = os.path.join(GEO, fname)
    if not os.path.exists(path):
        print(f"  (manca {fname}: saltato)")
        return
    d = json.load(open(path, encoding="utf-8"))
    shapes = []
    for ft in d["features"]:
        p = ft["properties"]
        shapes.append((str(int(p["ID_NIL"])), (p.get("NIL") or "").strip(), geojson_rings(ft["geometry"])))
    write(name, shapes)


def nil():
    path = os.path.join(WORK, "nil_geometry_wkt.csv")
    if not os.path.exists(path):
        print("  (manca data/work/nil_geometry_wkt.csv: eseguire prima il modulo 05)")
        return
    csv.field_size_limit(sys.maxsize if sys.maxsize < 2**31 else 2**31 - 1)
    shapes = []
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            shapes.append((row["nil"], "", wkt_rings(row["geom"])))
    write("nil_wkt", shapes)


if __name__ == "__main__":
    omi("zone_omi_2025_2.geojson", "omi2025")
    omi("_expl_f205_2011_1.geojson", "omi2011")
    nil()
    nil_geojson("nil_vigenti_ds964.geojson", "nilnew")   # NIL vigenti (PGT 2030) = geografia DS205
    nil_geojson("nil_vecchi.geojson", "nilold")          # NIL PGT 2012 = geografia del file dell'indice
