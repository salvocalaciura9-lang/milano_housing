"""Mappa della M4 sulle zone OMI (zonizzazione 2025 S2), con il ruolo di ogni zona
nell'analisi diff-in-diff (output/tables/m4_groups.csv, raggio 500 m).
Uso: python code/aux_map_m4.py <cartella_output>  -> map_m4.html (esportare in PNG
con un browser; output/figures/m4_map_omi_zones.png e' stata creata con Chromium, scala 2).
La linea tra le stazioni e' schematica (segmenti tra stazioni consecutive)."""
import csv, json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1]

# --- ruoli delle zone (zonizzazione 2014-2024; D37/D38 = ex D15, D39/D40 = ex D30) ---
roles = {}
with open(f'{ROOT}/output/tables/m4_groups.csv', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        c = r['cohort']
        if c == '':
            roles[r['zona']] = 'excl'
        elif float(c) == 0:
            roles[r['zona']] = 'ctrl' if r['matched'] == '1' else 'never'
        else:
            roles[r['zona']] = 't2023' if float(c) < 2024 else 't2025'
parent = {'D37': 'D15', 'D38': 'D15', 'D39': 'D30', 'D40': 'D30'}

STYLE = {  # fill, label
    't2023': ('#c4520f', 'Treated from 2023H1 (phase 1)'),
    't2025': ('#f2a65a', 'Treated from 2025H1 (phase 3)'),
    'ctrl':  ('#84b9f3', 'Matched never-exposed control'),
    'never': ('#e3edf8', 'Other never-exposed zone'),
    'excl':  ('#cfcfcf', 'Excluded: partly exposed or served by other lines'),
    'none':  ('#ffffff', 'Not in panel (incomplete rent series)'),
}

# --- geometrie ---
g = json.load(open(f'{ROOT}/data/geo/zone_omi_2025_2.geojson'))
zones = []
for ft in g['features']:
    code = ft['properties']['Zona'].strip()
    geom = ft['geometry']
    polys = [geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']
    role = roles.get(parent.get(code, code), 'none')
    zones.append((code, role, polys))

stations = []
with open(f'{ROOT}/data/raw/ds535_tpl_metrofermate.csv', encoding='utf-8') as f:
    for r in csv.DictReader(f, delimiter=';'):
        lines = r['linee'].replace(' ', '').split(',')
        stations.append((r['nome'].strip().upper(), lines, float(r['LONG_X_4326']), float(r['LAT_Y_4326'])))

PH1 = ['LINATE AEROPORTO', 'REPETTI', 'STAZIONE FORLANINI', 'ARGONNE', 'SUSA', 'DATEO']
PH2 = ['TRICOLORE', 'SAN BABILA']
ORDER = PH1 + PH2 + ['SFORZA-POLICLINICO', 'SANTA SOFIA', 'VETRA', 'DE AMICIS', 'SAN AMBROGIO',
                     'CONI ZUGNA', 'CALIFORNIA', 'BOLIVAR', 'TOLSTOJ', 'FRATTINI', 'GELSOMINI',
                     'SEGNERI', 'SAN CRISTOFORO']
m4 = {n: (x, y) for n, l, x, y in stations if '4' in l}
assert set(m4) == set(ORDER), set(m4) ^ set(ORDER)
other = [(x, y) for n, l, x, y in stations if '4' not in l]
phase = lambda n: 1 if n in PH1 else (2 if n in PH2 else 3)
PHC = {1: '#7a2e00', 2: '#b8860b', 3: '#e07b1f'}

# --- proiezione ---
# estensione: zone OMI + stazioni M4 (Linate Aeroporto e' fuori dal confine comunale) + margine di 600 m
xs = [p[0] for _, _, ps in zones for poly in ps for ring in poly for p in ring] + [v[0] + d for v in m4.values() for d in (-0.008, 0.008)]
ys = [p[1] for _, _, ps in zones for poly in ps for ring in poly for p in ring] + [v[1] + d for v in m4.values() for d in (-0.0055, 0.0055)]
lat0 = (min(ys) + max(ys)) / 2
kx = math.cos(math.radians(lat0))
W = 1000
sc = W / ((max(xs) - min(xs)) * kx)
H = (max(ys) - min(ys)) * sc
P = lambda x, y: ((x - min(xs)) * kx * sc, (max(ys) - y) * sc)
m_per_px = 110574 / sc          # metri per pixel (asse y)
R500 = 500 / m_per_px

def path(polys):
    return ''.join('M' + 'L'.join('%.1f,%.1f' % P(x, y) for x, y in ring) + 'Z' for poly in polys for ring in poly)

def centroid(polys):  # centroide dell'anello esterno piu' grande
    ring = max((poly[0] for poly in polys), key=len)
    pts = [P(x, y) for x, y in ring]
    a = cx = cy = 0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        c = x0 * y1 - x1 * y0; a += c; cx += (x0 + x1) * c; cy += (y0 + y1) * c
    return (cx / (3 * a), cy / (3 * a)) if a else pts[0]

svg = [f'<svg viewBox="-6 -6 {W+12:.0f} {H+12:.0f}" width="{W+12:.0f}" height="{H+12:.0f}" xmlns="http://www.w3.org/2000/svg" font-family="Helvetica, Arial, sans-serif">']
for code, role, polys in zones:
    svg.append(f'<path d="{path(polys)}" fill="{STYLE[role][0]}" fill-rule="evenodd" stroke="#6b6b6b" stroke-width="0.8"><title>{code}</title></path>')
# bacini di 500 m
for n in ORDER:
    x, y = P(*m4[n])
    svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{R500:.1f}" fill="none" stroke="#1f1f1f" stroke-width="0.9" stroke-dasharray="3 3" opacity="0.75"/>')
# altre linee
for x, y in other:
    px, py = P(x, y)
    svg.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="2.6" fill="#555" opacity="0.65"/>')
# linea M4 schematica
pts = ' '.join('%.1f,%.1f' % P(*m4[n]) for n in ORDER)
svg.append(f'<polyline points="{pts}" fill="none" stroke="#ffffff" stroke-width="6.5" stroke-linejoin="round"/>')
svg.append(f'<polyline points="{pts}" fill="none" stroke="#1f1f1f" stroke-width="3" stroke-linejoin="round"/>')
for n in ORDER:
    x, y = P(*m4[n])
    svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5.5" fill="{PHC[phase(n)]}" stroke="#fff" stroke-width="2"><title>{n.title()}</title></circle>')
# etichette delle zone
for code, role, polys in zones:
    cx, cy = centroid(polys)
    col = '#ffffff' if role == 't2023' else '#222'
    svg.append(f'<text x="{cx:.1f}" y="{cy+4:.1f}" text-anchor="middle" font-size="11" font-weight="bold" fill="{col}" '
               f'stroke="{"none" if role == "t2023" else "#ffffff"}" stroke-width="2.5" paint-order="stroke">{code}</text>')
# nomi dei capolinea e di San Babila
for n, dx, dy, anc in [('LINATE AEROPORTO', -4, -14, 'end'), ('SAN CRISTOFORO', -8, 16, 'end'), ('SAN BABILA', 0, -16, 'start')]:
    x, y = P(*m4[n])
    svg.append(f'<text x="{x+dx:.1f}" y="{y+dy:.1f}" text-anchor="{anc}" font-size="12" font-style="italic" fill="#111" stroke="#fff" stroke-width="3" paint-order="stroke">{n.title()}</text>')
# barra di scala 2 km
bx, by = W - 180, H - 20
L2 = 2000 / m_per_px
svg.append(f'<line x1="{bx}" y1="{by}" x2="{bx+L2:.1f}" y2="{by}" stroke="#222" stroke-width="3"/><text x="{bx+L2/2:.1f}" y="{by-8}" text-anchor="middle" font-size="12" fill="#222">2 km</text>')
svg.append('</svg>')

def sw(fill, stroke='#6b6b6b'):
    return f'<i style="background:{fill};border:1px solid {stroke}"></i>'
leg_z = ''.join(f'<div>{sw(STYLE[k][0])}{STYLE[k][1]}</div>' for k in ['t2023', 't2025', 'ctrl', 'never', 'excl', 'none'])
leg_s = (f'<div><b class="dot" style="background:{PHC[1]}"></b>Phase 1, Linate–Dateo (26 Nov 2022)</div>'
         f'<div><b class="dot" style="background:{PHC[2]}"></b>Phase 2, Dateo–San Babila (4 Jul 2023)</div>'
         f'<div><b class="dot" style="background:{PHC[3]}"></b>Phase 3, San Babila–San Cristoforo (12 Oct 2024)</div>'
         '<div><b class="ring"></b>500 m catchment of M4 stations</div>'
         '<div><b class="dot" style="background:#555;width:7px;height:7px;opacity:.65"></b>Stations of other metro lines</div>')
html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;background:#fff;font-family:Helvetica,Arial,sans-serif;color:#222}}.wrap{{display:inline-block;padding:20px 24px 14px}}
h1{{font-size:21px;margin:0 0 4px}}.lead{{font-size:13.5px;color:#444;margin:0 0 8px}}
.row{{display:flex;gap:18px;align-items:flex-start}}.leg{{font-size:13px;line-height:1.75;min-width:330px;padding-top:30px}}
.leg h3{{font-size:13px;margin:10px 0 2px;color:#111}}.leg i{{display:inline-block;width:15px;height:13px;margin-right:8px;vertical-align:-2px}}
.dot{{display:inline-block;width:11px;height:11px;border-radius:50%;margin-right:8px;vertical-align:-1px;border:2px solid #fff;box-shadow:0 0 0 1px #999}}
.ring{{display:inline-block;width:12px;height:12px;border-radius:50%;border:1.5px dashed #1f1f1f;margin-right:8px;vertical-align:-2px}}
.note{{font-size:10.5px;color:#555;max-width:1340px;line-height:1.35;margin-top:4px}}</style></head><body><div class="wrap">
<h1>The M4 metro line and the OMI zones of Milan</h1>
<p class="lead">Role of each OMI zone in the M4 difference-in-differences design (baseline rule: 500 m catchment, 20% exposure threshold)</p>
<div class="row">{"".join(svg)}<div class="leg"><h3>OMI zones</h3>{leg_z}<h3>M4 stations</h3>{leg_s}</div></div>
<div class="note">OMI zones: 2025 second-semester boundaries (Agenzia delle Entrate); D37–D38 and D39–D40 are the 2024 splits of D15 and D30 and take the role of their parent zone. Treated: at least 20% of the zone within 500 m of a newly opened M4 station and more than 500 m from other lines. Matched controls: for each treated zone, the three most similar never-exposed zones before the opening. The line is drawn schematically between consecutive stations. Phase 2 newly serves no zone above the threshold. Stations: Comune di Milano, ds535.</div>
</div></body></html>'''
open(os.path.join(OUT, 'map_m4.html'), 'w').write(html)
print('zones', len(zones), {k: sum(1 for z in zones if z[1] == k) for k in STYLE})
