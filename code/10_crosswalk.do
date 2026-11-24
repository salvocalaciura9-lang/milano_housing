*==============================================================================*
* 10_crosswalk.do
* Raccordo CAP - zone OMI - NIL. Due strade:
*  A. raccordi forniti in $AUX (consigliato se l'universita' o il Comune
*     forniscono una corrispondenza documentata):
*       xw_nil_cap.csv : nil, cap, w   (w = quota del NIL nel CAP; somma 1 per NIL)
*       xw_omi_cap.csv : zona, cap, w  (w = quota del CAP nella zona; somma 1 per CAP,
*                                       incluse le zone senza quotazioni)
*     facoltativi con pesi di superficie: xw_nil_cap_area.csv, xw_omi_cap_area.csv
*  B. costruzione dai civici residenziali attivi DS634 (che contengono gia' il
*     codice NIL) con point-in-polygon (geoinpoly) su poligoni CAP e OMI in WGS84.
*     Versione "main": pesi = numero di civici residenziali.
*     Versione "pop":  ogni civico pesa residenti NIL 2019 / civici del NIL
*                      (cambia solo i pesi OMI -> CAP).
* I pesi sono fissi nel tempo (geografia di riferimento unica). Le quantita'
* allocate restano stime: vanno etichettate come allocate.
*
* Output: $WORK/xw_nil_cap_<v>.dta, $WORK/xw_omi_cap_<v>.dta, global XW_VERSIONS
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "10 - RACCORDO GEOGRAFICO CAP - OMI - NIL" _n "{hline 78}"

global XW_OK 0
global XW_VERSIONS ""
global CAPSHP_OK 0

*------------------------------------------------------------------------------*
* Programmi locali
*------------------------------------------------------------------------------*
capture program drop xwimport_nil
program define xwimport_nil
    args file ver
    imp_csv using "`file'"
    getvar nil, pattern("(^| )(id_)?nil( |$)")
    getvar cap, pattern("(^| )cap( |$)")
    getvar w,   pattern("(^| )(w|peso|weight)( |$)")
    keep nil cap w
    tonum nil cap w
    save "$WORK/xw_nil_cap_`ver'.dta", replace
end

capture program drop xwimport_omi
program define xwimport_omi
    args file ver
    imp_csv using "`file'"
    getvar zona, pattern("(^| )zona( |$)")
    getvar cap,  pattern("(^| )cap( |$)")
    getvar w,    pattern("(^| )(w|peso|weight)( |$)")
    keep zona cap w
    tonum cap w
    replace zona = upper(ustrtrim(zona))
    save "$WORK/xw_omi_cap_`ver'.dta", replace
end

capture program drop xwcheck
program define xwcheck
    args ver
    * NIL -> CAP
    use "$WORK/xw_nil_cap_`ver'.dta", clear
    isid nil cap
    assert !missing(w) & w >= 0
    bysort nil: egen double ws = total(w)
    quietly summarize ws
    if abs(r(min) - 1) > 0.001 | abs(r(max) - 1) > 0.001 {
        di as error "  [`ver'] somma dei pesi NIL->CAP diversa da 1 (min " %6.4f r(min) ///
            ", max " %6.4f r(max) "): rinormalizzo per NIL"
        quietly replace w = w/ws
    }
    drop ws
    bysort nil: egen double wmax = max(w)
    bysort nil: gen byte ncap = _N
    egen byte tagn = tag(nil)
    di as txt "  [`ver'] NIL -> CAP: CAP per NIL e peso massimo (1 = NIL interamente in un CAP)"
    summarize ncap wmax if tagn
    drop wmax ncap tagn
    save "$WORK/xw_nil_cap_`ver'.dta", replace
    preserve
    keep nil
    duplicates drop
    merge 1:1 nil using "$WORK/ref_nil.dta"
    di as txt "  [`ver'] NIL senza raccordo (_merge = 2) o assenti dal DS205 (_merge = 1):"
    list nil _merge if _merge != 3, noobs
    restore
    preserve
    keep cap
    duplicates drop
    merge 1:1 cap using "$WORK/ref_cap.dta"
    di as txt "  [`ver'] CAP fiscali senza NIL (_merge = 2) o assenti dai dati IRPEF (_merge = 1):"
    list cap _merge if _merge != 3, noobs
    restore

    * OMI -> CAP
    use "$WORK/xw_omi_cap_`ver'.dta", clear
    isid zona cap
    assert !missing(w) & w >= 0
    bysort cap: egen double ws = total(w)
    quietly summarize ws
    if abs(r(min) - 1) > 0.001 | abs(r(max) - 1) > 0.001 {
        di as error "  [`ver'] somma dei pesi OMI->CAP diversa da 1 (min " %6.4f r(min) ///
            ", max " %6.4f r(max) "): rinormalizzo per CAP"
        quietly replace w = w/ws
    }
    drop ws
    save "$WORK/xw_omi_cap_`ver'.dta", replace
    preserve
    merge m:1 zona using "$WORK/ref_zona.dta", keep(master match)
    gen double w_unq = w*(_merge == 1)
    collapse (sum) w_unq, by(cap)
    di as txt "  [`ver'] quota di ciascun CAP in zone senza quotazioni NORMALE (es. C13, R2, NESSUNA):"
    list cap w_unq if w_unq > 0, noobs
    restore
end

*------------------------------------------------------------------------------*
* Riferimenti per i controlli
*------------------------------------------------------------------------------*
use "$WORK/irpef_cap_year.dta", clear
keep cap
duplicates drop
save "$WORK/ref_cap.dta", replace
use "$WORK/ds205_nil_year.dta", clear
keep nil
duplicates drop
save "$WORK/ref_nil.dta", replace
use "$WORK/omi_zone_year.dta", clear
keep if inrange(anno, $Y0, $Y1) & !missing(R_mid)
keep zona
duplicates drop
save "$WORK/ref_zona.dta", replace

*------------------------------------------------------------------------------*
* A. Raccordi forniti
*------------------------------------------------------------------------------*
capture confirm file "$AUX/$F_XW_NILCAP"
local hasA1 = (_rc == 0)
capture confirm file "$AUX/$F_XW_OMICAP"
local hasA2 = (_rc == 0)

if `hasA1' & `hasA2' {
    di as txt "  Uso i raccordi forniti in $AUX"
    xwimport_nil "$AUX/$F_XW_NILCAP" main
    xwimport_omi "$AUX/$F_XW_OMICAP" main
    global XW_VERSIONS "main"
}
else {
    *--------------------------------------------------------------------------*
    * B. Costruzione dai civici DS634 e dai poligoni CAP e OMI
    *--------------------------------------------------------------------------*
    capture confirm file "$GEO/$F_CIVICI"
    local c1 = (_rc == 0)
    capture confirm file "$GEO/$SHP_CAP.shp"
    local c2 = (_rc == 0)
    capture confirm file "$GEO/$SHP_OMI.shp"
    local c3 = (_rc == 0)
    if !(`c1' & `c2' & `c3') {
        di as error "  Raccordo non disponibile. Servono in $AUX: $F_XW_NILCAP e $F_XW_OMICAP"
        di as error "  oppure in $GEO: $F_CIVICI, $SHP_CAP.shp, $SHP_OMI.shp (WGS84)."
        di as error "  Restano valide le analisi alle geografie native (moduli 06-09);"
        di as error "  i moduli 11 e 12 vengono saltati."
        exit
    }
    capture which geoinpoly
    if _rc {
        di as error "  Pacchetto geoinpoly non installato (ssc install geoinpoly): raccordo non costruito"
        exit
    }

    local here "`c(pwd)'"
    quietly cd "$GEO"
    capture noisily spshape2dta $SHP_CAP, replace saving(cap_shape)
    local rc1 = _rc
    capture noisily spshape2dta $SHP_OMI, replace saving(omi_shape)
    local rc2 = _rc
    quietly cd "`here'"
    if `rc1' | `rc2' {
        di as error "  Conversione degli shapefile CAP/OMI non riuscita"
        exit
    }
    foreach s in cap omi {
        use "$GEO/`s'_shape_shp.dta", clear
        quietly summarize _Y
        if r(min) < 44 | r(max) > 47 {
            di as error "  `s'_shape: coordinate non in gradi WGS84 (_Y tra " r(min) " e " r(max) ")."
            di as error "  Riproiettare lo shapefile in EPSG:4326 (es. QGIS) e rieseguire."
            exit
        }
    }

    * codici CAP e zona OMI negli attributi dei poligoni
    use "$GEO/cap_shape.dta", clear
    if "$SHP_CAP_ID" != "" {
        local lc = lower("$SHP_CAP_ID")
        getvar capcode, pattern("^`lc'( |$)")
    }
    else {
        detectcode, regex("^201[0-9][0-9]$")
        rename `r(varname)' capcode
    }
    tonum capcode
    keep _ID capcode
    rename capcode cap
    save "$WORK/cap_ids.dta", replace
    global CAPSHP_OK 1

    use "$GEO/omi_shape.dta", clear
    if "$SHP_OMI_ID" != "" {
        local lc = lower("$SHP_OMI_ID")
        getvar zonacode, pattern("^`lc'( |$)")
    }
    else {
        detectcode, regex("^[A-Z][0-9]{1,2}$")
        rename `r(varname)' zonacode
    }
    capture confirm string variable zonacode
    if _rc tostring zonacode, replace
    replace zonacode = upper(ustrtrim(zonacode))
    keep _ID zonacode
    rename zonacode zona
    save "$WORK/omi_ids.dta", replace

    * civici residenziali attivi
    imp_csv using "$GEO/$F_CIVICI"
    getvar lat,   pattern("lat_wgs84")
    getvar lon,   pattern("long_wgs84")
    getvar nil,   pattern("(^| )id_nil( |$)")
    getvar resid, pattern("(^| )residenziale( |$)")
    getvar dsopp, pattern("data_soppressione") optional
    local kv lat lon nil resid
    capture confirm variable dsopp
    if !_rc local kv `kv' dsopp
    keep `kv'
    tonum `kv'
    di as txt "  civici nel file: " _N
    keep if resid == 1
    capture confirm variable dsopp
    if !_rc keep if dsopp == 0 | missing(dsopp)
    drop if missing(lat, lon)
    di as txt "  civici residenziali attivi con coordinate: " _N
    gen long pid = _n

    foreach s in cap omi {
        geoinpoly lat lon using "$GEO/`s'_shape_shp.dta"
        bysort pid: gen int nmatch = _N if !missing(_ID)
        quietly count if nmatch > 1 & !missing(nmatch)
        di as txt "  `s': punti su piu' poligoni (confini), tenuto il primo: " r(N)
        bysort pid (_ID): keep if _n == 1
        merge m:1 _ID using "$WORK/`s'_ids.dta", keep(master match) nogen
        drop _ID nmatch
    }
    quietly count if missing(cap)
    di as txt "  civici fuori dai poligoni CAP: " r(N)
    quietly count if zona == ""
    di as txt "  civici fuori dai poligoni OMI: " r(N)
    quietly count if missing(nil)
    di as txt "  civici senza codice NIL: " r(N)
    save "$WORK/civici_geo.dta", replace

    * versione main: numero di civici residenziali
    preserve
    drop if missing(nil) | missing(cap)
    contract nil cap, freq(n)
    bysort nil: egen double tot = total(n)
    gen double w = n/tot
    keep nil cap w n
    export delimited using "$TAB/xw_nil_cap_built.csv", replace
    keep nil cap w
    save "$WORK/xw_nil_cap_main.dta", replace
    save "$WORK/xw_nil_cap_pop.dta", replace
    restore

    preserve
    drop if missing(cap)
    replace zona = "NESSUNA" if zona == ""
    contract zona cap, freq(n)
    bysort cap: egen double tot = total(n)
    gen double w = n/tot
    keep zona cap w n
    export delimited using "$TAB/xw_omi_cap_built.csv", replace
    keep zona cap w
    save "$WORK/xw_omi_cap_main.dta", replace
    restore

    * versione pop: civici pesati con i residenti 2019 del NIL
    preserve
    use "$WORK/ds205_nil_year.dta", clear
    keep if year == 2019
    keep nil pop
    tempfile p19
    save `p19'
    restore
    merge m:1 nil using `p19', keep(master match) nogen
    bysort nil: gen double nciv = _N if !missing(nil)
    gen double wt = pop/nciv
    drop if missing(cap) | missing(wt)
    replace zona = "NESSUNA" if zona == ""
    collapse (sum) wt, by(zona cap)
    bysort cap: egen double tot = total(wt)
    gen double w = wt/tot
    keep zona cap w
    save "$WORK/xw_omi_cap_pop.dta", replace

    global XW_VERSIONS "main pop"
}

* pesi di superficie (calcolati in GIS) come ulteriore sensibilita'
capture confirm file "$AUX/$F_XW_NILCAP_AREA"
local a1 = (_rc == 0)
capture confirm file "$AUX/$F_XW_OMICAP_AREA"
local a2 = (_rc == 0)
if `a1' & `a2' {
    xwimport_nil "$AUX/$F_XW_NILCAP_AREA" area
    xwimport_omi "$AUX/$F_XW_OMICAP_AREA" area
    global XW_VERSIONS "$XW_VERSIONS area"
}

foreach v of global XW_VERSIONS {
    xwcheck `v'
}
global XW_OK 1
di as txt "  Raccordi disponibili: $XW_VERSIONS"
