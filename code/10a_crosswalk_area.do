*==============================================================================*
* 10a_crosswalk_area.do
* Raccordi CAP - NIL - zone OMI con PESI DI SUPERFICIE, costruiti con una
* griglia regolare di punti (~28 m) assegnati ai poligoni con geoinpoly.
* Ogni punto rappresenta la stessa superficie, quindi i conteggi di punti
* approssimano le aree di intersezione.
*
* Input in $GEO:
*   CAPZONE_Milano.shp/.dbf        CAP (Poste Italiane, demo), WGS84, 38 CAP
*   omi2025_coords.csv/_attr.csv   zone OMI 2025-2 (da aux_geo_to_stata.py)
*   omi2011_coords.csv/_attr.csv   zone OMI 2011-1 (facoltativo, confronto)
*   nilnew_coords.csv/_attr.csv    NIL VIGENTI (DS964, Milano 2030) = geografia del DS205
*   nilold_coords.csv/_attr.csv    NIL PGT 2012 = geografia del file dell'indice
*                                  (in mancanza: nil_wkt, geometrie WKT dell'indice)
* I pesi NIL -> CAP e NIL -> OMI usano i NIL VIGENTI, perche' popolazione e
* uscite (DS205) sono su quella geografia. Il raccordo NIL vecchi -> NIL vigenti
* serve a portare le misure dell'indice (2011-21) sulla geografia del DS205.
* Le zone OMI 2025 coincidono con quelle 2019-2023 tranne la revisione 2024:
*   D15 -> D37 + D38 (+ Ortomercato passato a D16)   ricodificate in D15
*   D30 -> D39 + D40                                 ricodificate in D30
*
* Output in $AUX (letti dal modulo 10, strada A):
*   xw_nil_cap.csv       nil, cap, w  (quota della superficie del NIL in ogni CAP)
*   xw_omi_cap.csv       zona, cap, w (quota della superficie del CAP in ogni zona)
*   xw_nil_omi_area.csv  nil, zona, w (quota del NIL in ogni zona OMI 2019-23)
*   xw_nil_omi2011_area.csv  idem con le zone OMI 2011
*   xw_nilold_nilnew.csv nil_old, nil, w (quota della superficie del NIL vigente
*                        che proviene da ciascun NIL vecchio; somma 1 per NIL vigente)
* Output in $TAB: omi_zone_2011_vs_2021.csv (sovrapposizione delle zonizzazioni)
*
* NB: pesi di superficie, non di popolazione: parchi e aree non residenziali
* pesano come le aree abitate. Le quantita' allocate sono stime.
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "10a - RACCORDI CON PESI DI SUPERFICIE (GRIGLIA)" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in GEO:data/geo AUX:data/auxdata WORK:data/work TAB:output/tables {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}

local ok 1
foreach f in "CAPZONE_Milano.shp" "omi2025_coords.csv" "omi2025_attr.csv" "nilnew_coords.csv" "nilnew_attr.csv" {
    capture confirm file "$GEO/`f'"
    if _rc {
        di as error "  manca $GEO/`f'"
        local ok 0
    }
}
if !`ok' {
    di as error "  10a saltato (eseguire prima code/aux_geo_to_stata.py)"
    exit
}
capture which geoinpoly
if _rc {
    capture noisily ssc install geoinpoly, replace
    capture which geoinpoly
    if _rc {
        di as error "  geoinpoly non disponibile: 10a saltato"
        exit
    }
}

*------------------------------------------------------------------------------*
* Poligoni in formato Stata
*------------------------------------------------------------------------------*
local here "`c(pwd)'"
quietly cd "$GEO"
spshape2dta CAPZONE_Milano, replace saving(cap_poste)
quietly cd "`here'"
use "$GEO/cap_poste.dta", clear
gen long cap = real(CAP)
keep _ID cap ABITAZIONI
rename ABITAZIONI abitazioni_poste
isid cap
di as txt "  CAP nello shapefile: " _N
save "$WORK/xwa_cap_ids.dta", replace

local oldsrc "nilold"
capture confirm file "$GEO/nilold_coords.csv"
if _rc local oldsrc "nil_wkt"
foreach s in omi2025 omi2011 nilnew `oldsrc' {
    capture confirm file "$GEO/`s'_coords.csv"
    if _rc continue
    import delimited using "$GEO/`s'_coords.csv", varnames(1) case(preserve) clear
    gen long shape_order = _n
    save "$WORK/xwa_`s'_shp.dta", replace
    import delimited using "$GEO/`s'_attr.csv", varnames(1) case(preserve) stringcols(2 3) clear
    save "$WORK/xwa_`s'_ids.dta", replace
}

*------------------------------------------------------------------------------*
* Griglia di punti sull'estensione dei CAP
*------------------------------------------------------------------------------*
use "$GEO/cap_poste_shp.dta", clear
quietly summarize _X
local x0 = r(min)
local x1 = r(max)
quietly summarize _Y
local y0 = r(min)
local y1 = r(max)
local dx = 0.00035     // ~27 m in longitudine a 45,5 gradi N
local dy = 0.00025     // ~28 m in latitudine
local nx = ceil((`x1' - `x0')/`dx')
local ny = ceil((`y1' - `y0')/`dy')
clear
set obs `=`nx'*`ny''
gen long pid = _n
gen double lon = `x0' + `dx'*(mod(pid - 1, `nx') + 0.5)
gen double lat = `y0' + `dy'*(floor((pid - 1)/`nx') + 0.5)
di as txt "  griglia: `nx' x `ny' = " _N " punti"

* assegna ogni punto al poligono che lo contiene (primo in caso di confine)
capture program drop xwa_assign
program define xwa_assign
    args shp ids codevar newvar
    geoinpoly lat lon using "`shp'"
    bysort pid (_ID): gen int __nm = _N if !missing(_ID)
    quietly count if __nm > 1 & !missing(__nm)
    di as txt "  `newvar': punti su piu' poligoni (tenuto il primo): " r(N)
    bysort pid (_ID): keep if _n == 1
    merge m:1 _ID using "`ids'", keep(master match) nogen keepusing(`codevar')
    rename `codevar' `newvar'
    drop _ID __nm
end

xwa_assign "$GEO/cap_poste_shp.dta" "$WORK/xwa_cap_ids.dta" cap cap
keep if !missing(cap)
di as txt "  punti dentro i 38 CAP: " _N " (~" %5.1f _N*27*28/1e6 " km2)"

xwa_assign "$WORK/xwa_nilnew_shp.dta" "$WORK/xwa_nilnew_ids.dta" code nil
destring nil, replace
capture confirm file "$WORK/xwa_`oldsrc'_shp.dta"
if !_rc {
    xwa_assign "$WORK/xwa_`oldsrc'_shp.dta" "$WORK/xwa_`oldsrc'_ids.dta" code nil_old
    destring nil_old, replace
}
else gen int nil_old = .
xwa_assign "$WORK/xwa_omi2025_shp.dta" "$WORK/xwa_omi2025_ids.dta" code zona25
capture confirm file "$WORK/xwa_omi2011_shp.dta"
if !_rc {
    xwa_assign "$WORK/xwa_omi2011_shp.dta" "$WORK/xwa_omi2011_ids.dta" code zona11
}
else gen str3 zona11 = ""

* revisione 2024 delle zone: ritorno ai codici 2019-2023
gen str8 zona = zona25
replace zona = "D15" if inlist(zona25, "D37", "D38")
replace zona = "D30" if inlist(zona25, "D39", "D40")

quietly count if missing(nil)
di as txt "  punti nei CAP ma fuori dai NIL: " r(N) " (" %4.2f 100*r(N)/_N "%)"
quietly count if zona == ""
di as txt "  punti nei CAP ma fuori dalle zone OMI 2025: " r(N) " (" %4.2f 100*r(N)/_N "%)"
compress
save "$WORK/xwa_grid.dta", replace

*------------------------------------------------------------------------------*
* NIL vecchi (PGT 2012, file dell'indice) -> NIL vigenti (DS205)
* w = quota della superficie del NIL vigente che cade in ciascun NIL vecchio
*------------------------------------------------------------------------------*
preserve
drop if missing(nil) | missing(nil_old)
contract nil_old nil, freq(n)
bysort nil: egen double tot = total(n)
gen double w = n/tot
bysort nil_old: egen double tot_old = total(n)
gen double w_old = n/tot_old
label variable w     "Quota del NIL vigente proveniente dal NIL vecchio"
label variable w_old "Quota del NIL vecchio che cade nel NIL vigente"
bysort nil: egen double wmax = max(w)
egen byte tg = tag(nil)
di as txt _n "  Raccordo NIL vecchi -> NIL vigenti (`oldsrc'):"
quietly count if tg
di as txt "    NIL vigenti coperti: " r(N)
foreach t in 0.99 0.95 0.80 0.50 {
    quietly count if tg & wmax >= `t'
    di as txt "    NIL vigenti con almeno il " %3.0f 100*`t' "% da un solo NIL vecchio: " r(N)
}
* elenco dei NIL vigenti che cambiano in modo rilevante (per la relazione)
foreach k in new old {
    tempfile nm_`k'
    local src = cond("`k'" == "new", "nilnew", "`oldsrc'")
    local key = cond("`k'" == "new", "nil", "nil_old")
    frame create __nm
    frame __nm {
        use "$WORK/xwa_`src'_ids.dta", clear
        gen int `key' = real(code)
        rename descr name_`k'
        keep `key' name_`k'
        duplicates drop `key', force
        save `nm_`k''
    }
    frame drop __nm
    merge m:1 `key' using `nm_`k'', keep(master match) nogen
}
gen byte same_code = (nil == nil_old)
bysort nil: egen byte same_main = max(same_code & w == wmax)
quietly count if tg & wmax >= 0.99 & same_main
di as txt "    NIL vigenti con lo stesso codice e >= 99% della superficie dal NIL vecchio: " r(N)
di as txt "    (stessi confini: cambiano solo i nomi, es. 74 SACCO -> ROSERIO)"
gsort nil -w
di as txt "  NIL vigenti con meno del 90% da un solo NIL vecchio (prime due provenienze):"
by nil: gen byte rk = _n
list nil name_new nil_old name_old w if wmax < 0.90 & rk <= 2 & w >= 0.05, noobs sepby(nil)
keep nil_old nil w w_old n wmax name_old name_new
export delimited using "$AUX/xw_nilold_nilnew.csv", replace
restore

*------------------------------------------------------------------------------*
* Poligoni delle 41 zone OMI 2019-23 (per mappe e test spaziali)
* D37+D38 -> D15, D39+D40 -> D30 (stesso _ID, piu' anelli). Centroidi = media
* dei punti della griglia della zona.
*------------------------------------------------------------------------------*
preserve
drop if zona == ""
collapse (mean) _CX=lon _CY=lat (count) npts=pid, by(zona)
sort zona
gen long _ID = _n
order _ID _CX _CY zona npts
tempfile zc
save `zc'
use "$WORK/xwa_omi2025_ids.dta", clear
rename code zona25
gen str8 zona = zona25
replace zona = "D15" if inlist(zona25, "D37", "D38")
replace zona = "D30" if inlist(zona25, "D39", "D40")
rename _ID _ID25
merge m:1 zona using `zc', keep(match) nogen keepusing(_ID)
keep _ID25 _ID
tempfile idmap
save `idmap'
use "$WORK/xwa_omi2025_shp.dta", clear
rename _ID _ID25
merge m:1 _ID25 using `idmap', keep(match) nogen
sort _ID _ID25 shape_order
drop _ID25 shape_order
by _ID: gen long shape_order = _n
order _ID _X _Y shape_order
save "$GEO/omi_zone_shape_shp.dta", replace
use `zc', clear
di as txt "  Poligoni delle zone OMI 2019-23: " _N " zone (attese 41)"
save "$GEO/omi_zone_shape.dta", replace
restore

*------------------------------------------------------------------------------*
* Pesi
*------------------------------------------------------------------------------*
* NIL -> CAP: quota della superficie del NIL in ciascun CAP (somma 1 per NIL)
preserve
drop if missing(nil)
contract nil cap, freq(n)
bysort nil: egen double tot = total(n)
gen double w = n/tot
bysort nil: egen double wmax = max(w)
egen byte tg = tag(nil)
quietly count if tg
di as txt "  NIL nel raccordo: " r(N) "; NIL interamente (>95%) in un solo CAP:"
count if tg & wmax > 0.95
keep nil cap w n
export delimited using "$AUX/xw_nil_cap.csv", replace
restore

* OMI -> CAP: quota della superficie del CAP in ciascuna zona (somma 1 per CAP)
preserve
replace zona = "NESSUNA" if zona == ""
contract zona cap, freq(n)
bysort cap: egen double tot = total(n)
gen double w = n/tot
keep zona cap w n
export delimited using "$AUX/xw_omi_cap.csv", replace
restore

* NIL -> zone OMI (2019-23 e 2011): per portare le quotazioni ai NIL
foreach z in zona zona11 {
    preserve
    drop if missing(nil) | `z' == ""
    contract nil `z', freq(n)
    bysort nil: egen double tot = total(n)
    gen double w = n/tot
    keep nil `z' w n
    local out = cond("`z'" == "zona", "xw_nil_omi_area.csv", "xw_nil_omi2011_area.csv")
    if _N > 0 export delimited using "$AUX/`out'", replace
    restore
}

* confronto delle zonizzazioni OMI 2011 e 2019-23
preserve
drop if zona11 == "" | zona == ""
contract zona11 zona, freq(n)
bysort zona11: egen double tot11 = total(n)
bysort zona:   egen double tot21 = total(n)
gen double sh_of_2011 = n/tot11
gen double sh_of_2021 = n/tot21
label variable sh_of_2011 "Quota della zona 2011 che cade nella zona 2019-23"
label variable sh_of_2021 "Quota della zona 2019-23 che cade nella zona 2011"
gsort zona11 -n
if _N > 0 {
    export delimited zona11 zona n sh_of_2011 sh_of_2021 using "$TAB/omi_zone_2011_vs_2021.csv", replace
    bysort zona11: egen double maxsh = max(sh_of_2011)
    egen byte tg = tag(zona11)
    di as txt "  zone 2011: quota massima finita in una sola zona 2019-23"
    summarize maxsh if tg, detail
}
restore

di as txt "  Raccordi di superficie scritti in $AUX"
