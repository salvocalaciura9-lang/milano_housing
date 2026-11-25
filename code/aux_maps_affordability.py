"""Mappe dell'affordability per NIL, 2015 e 2024 (indice A60, soglia 40%).
Uso: python code/aux_maps_affordability.py <cartella_output>; crea maps_both.html,
map_2015.html e map_2024.html (aprire nel browser ed esportare in PNG).
Le PNG in output/figures sono state create cosi' con Chromium (scala 2)."""
import json, math, sys
import pandas as pd

import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1]

a = pd.read_stata(f'{ROOT}/data/work/aff_nil_year.dta')
w = a[a.year.between(2015, 2024)]
cnt = w.groupby('nil').A60.count()
panel = set(cnt[cnt == 10].index.astype(int))
val = {yr: {int(r.nil): float(r.A60) for r in w[(w.year == yr) & w.nil.isin(panel)].itertuples()} for yr in (2015, 2024)}
share = {yr: (sum(v > 0.40 for v in val[yr].values()), len(val[yr])) for yr in val}

g = json.load(open(f'{ROOT}/data/geo/nil_vigenti_ds964.geojson'))
feats = []
for f in g['features']:
    geom = f['geometry']
    polys = [geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']
    feats.append((int(f['properties']['ID_NIL']), f['properties']['NIL'], polys))

xs = [p[0] for _, _, ps in feats for poly in ps for ring in poly for p in ring]
ys = [p[1] for _, _, ps in feats for poly in ps for ring in poly for p in ring]
lat0 = (min(ys) + max(ys)) / 2
kx = math.cos(math.radians(lat0))
W = 520
sc = W / ((max(xs) - min(xs)) * kx)
H = (max(ys) - min(ys)) * sc

def proj(x, y):
    return ((x - min(xs)) * kx * sc, (max(ys) - y) * sc)

# Diverging scale centred on the 40% threshold: green (affordable) -> neutral -> red.
STOPS = [(0.20, (26, 110, 60)), (0.30, (120, 186, 120)), (0.40, (243, 240, 228)),
         (0.55, (240, 160, 120)), (0.70, (205, 80, 65)), (0.90, (128, 20, 28))]

def color(v):
    v = min(max(v, STOPS[0][0]), STOPS[-1][0])
    for (v0, c0), (v1, c1) in zip(STOPS, STOPS[1:]):
        if v <= v1:
            t = (v - v0) / (v1 - v0)
            return '#%02x%02x%02x' % tuple(round(c0[i] + t * (c1[i] - c0[i])) for i in range(3))

NODATA = '#d9d9d9'

def path(polys):
    d = []
    for poly in polys:
        for ring in poly:
            pts = [proj(x, y) for x, y in ring]
            d.append('M' + 'L'.join(f'{x:.1f},{y:.1f}' for x, y in pts) + 'Z')
    return ''.join(d)

def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;')

def svg_map(yr):
    out = [f'<svg viewBox="-4 -4 {W+8:.0f} {H+8:.0f}" width="{W+8:.0f}" height="{H+8:.0f}" xmlns="http://www.w3.org/2000/svg">']
    for nil, name, polys in feats:
        v = val[yr].get(nil)
        fill = color(v) if v is not None else NODATA
        tip = f'{esc(name.title())} ({nil}): ' + (f'{100*v:.1f}%' if v is not None else 'excluded')
        out.append(f'<path d="{path(polys)}" fill="{fill}" fill-rule="evenodd" stroke="#ffffff" stroke-width="0.8"><title>{tip}</title></path>')
    for nil, name, polys in feats:
        v = val[yr].get(nil)
        if v is not None and v > 0.40:
            out.append(f'<path d="{path(polys)}" fill="none" fill-rule="evenodd" stroke="#1f1f1f" stroke-width="1.4" stroke-linejoin="round" pointer-events="none"/>')
    out.append('</svg>')
    return '\n'.join(out)

# Legend: continuous bar 20%..90% with a marker at the 40% threshold.
LW = 440
def lx(v): return 20 + (v - 0.20) / 0.70 * LW
grad = ''.join(f'<stop offset="{(v-0.20)/0.70:.4f}" stop-color="{color(v)}"/>' for v in [0.20 + i * 0.01 for i in range(71)])
ticks = ''.join(f'<line x1="{lx(v):.1f}" x2="{lx(v):.1f}" y1="34" y2="40" stroke="#555"/><text x="{lx(v):.1f}" y="54" text-anchor="middle">{int(v*100)}%</text>' for v in (0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9))
legend = f'''<svg width="{LW+260}" height="66" xmlns="http://www.w3.org/2000/svg" font-family="Helvetica, Arial, sans-serif" font-size="12" fill="#333">
<defs><linearGradient id="g">{grad}</linearGradient></defs>
<rect x="20" y="16" width="{LW}" height="18" fill="url(#g)"/>
{ticks}
<line x1="{lx(0.40):.1f}" x2="{lx(0.40):.1f}" y1="10" y2="40" stroke="#111" stroke-width="2"/>
<text x="{lx(0.40):.1f}" y="9" text-anchor="middle" font-weight="bold">40% OECD threshold</text>
<rect x="{LW+50}" y="16" width="18" height="18" fill="{NODATA}"/>
<text x="{LW+74}" y="30">Excluded / no OMI data</text>
<rect x="{LW+50}" y="40" width="18" height="18" fill="#f0a078" stroke="#1f1f1f" stroke-width="1.4"/>
<text x="{LW+74}" y="54">Outlined: above 40%</text>
</svg>'''

def panel_html(yr, single=False):
    k, n = share[yr]
    return f'''<div class="panel"><div class="yr">{yr}</div>
<div class="sub">{k} of {n} NILs above the threshold ({100*k/n:.1f}%)</div>{svg_map(yr)}</div>'''

CSS = '''body{margin:0;background:#fff;font-family:Helvetica,Arial,sans-serif;color:#222}
.wrap{padding:22px 26px 16px;display:inline-block}
h1{font-size:20px;margin:0 0 4px}.lead{font-size:13px;color:#444;margin:0 0 14px}
.maps{display:flex;gap:18px}.panel{text-align:center}.yr{font-size:18px;font-weight:bold}
.sub{font-size:12.5px;color:#444;margin:2px 0 4px}.leg{margin-top:6px;text-align:center}
.note{font-size:10.5px;color:#555;max-width:1080px;margin-top:6px;line-height:1.35}'''

NOTE = ('Index: annual OMI rent of a 60 m&sup2; dwelling (midpoint, civil dwellings in normal condition, area-weighted from OMI zones to NILs) '
        'divided by the median net income of Milanese taxpayers (EUR 17,370 in 2015; EUR 21,559 in 2024). Colours use the same scale in both years. '
        'Grey: NILs with fewer than 500 residents in 2019 or without OMI rent in every year 2015&ndash;2024. '
        'Source: authors&rsquo; elaboration on OMI (Agenzia delle Entrate) and Comune di Milano data.')

def page(body):
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body><div class="wrap">{body}</div></body></html>'

both = page(f'''<h1>Rent affordability by NIL, 2015 and 2024</h1>
<p class="lead">Annual rent of a standard 60 m&sup2; flat as a share of the median net income of Milanese taxpayers</p>
<div class="maps">{panel_html(2015)}{panel_html(2024)}</div><div class="leg">{legend}</div><div class="note">{NOTE}</div>''')
open(f'{OUT}/maps_both.html', 'w').write(both)
for yr in (2015, 2024):
    open(f'{OUT}/map_{yr}.html', 'w').write(page(f'''<h1>Rent affordability by NIL</h1>
<p class="lead">Annual rent of a standard 60 m&sup2; flat as a share of the median net income of Milanese taxpayers</p>
{panel_html(yr)}<div class="leg">{legend}</div><div class="note" style="max-width:540px">{NOTE}</div>'''))
print(share, round(W), round(H))
