*==============================================================================*
* 20_nil_typology.do
* Quanto sono omogenei i NIL? Tipologia dei quartieri per composizione dei
* residenti nel 2014 (prima della M4, dopo la revisione anagrafica post-censimento)
*
* Variabili (standardizzate): quota 0-14, 25-39, 65+, stranieri, stranieri da paesi
* ad alto reddito, famiglie unipersonali, capofamiglia sotto i 35 anni, nati per
* 1.000 residenti, istruzione al censimento 2011 (indice del paper).
* Metodo: k-medie con k = 5 gruppi (seed fisso, 50 ripartenze: si tiene la
* soluzione con la minore varianza interna). Quota di varianza spiegata dai gruppi
* per ogni variabile = misura di quanto i gruppi sono omogenei al loro interno.
*
* Output: $WORK/nil_typology.dta, $TAB/nil_typology.csv, nil_typology_means.csv,
*         $FIG/nil_typology_map.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "20 - TIPOLOGIA DEI NIL PER COMPOSIZIONE DEI RESIDENTI (2014)" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in WORK:data/work TAB:output/tables FIG:output/figures {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$SMALL_NIL" == "" global SMALL_NIL 500
capture confirm file "$WORK/nil_composition_year.dta"
if _rc {
    di as error "  manca nil_composition_year.dta (modulo 03c): 20 saltato"
    exit
}
local K 5
local Y0 2014

use "$WORK/nil_composition_year.dta", clear
bysort nil: egen double pop19 = max(cond(year == 2019, pop27, .))
keep if year == `Y0' & pop19 >= $SMALL_NIL
* nomi e istruzione 2011 (indice del paper portato sui NIL vigenti, modulo 07b)
preserve
use "$WORK/ds205_nil_year.dta", clear
keep if year == 2019
keep nil name
tempfile nm
save `nm'
restore
merge 1:1 nil using `nm', keep(master match) nogen
local edu ""
capture merge 1:1 nil using "$WORK/gentrif_nilnew.dta", keepusing(edu2011) keep(master match) nogen
capture confirm variable edu2011
if _rc == 0 local edu "edu2011"
* un NIL senza istruzione non entra nella tipologia
if "`edu'" != "" drop if missing(edu2011)

local X "sh_g0014 sh_g2539 sh_g65 sh_for27 sh_hi sh_fam1_h sh_head35 birth_rate `edu'"
di as txt "  Variabili: `X'"
egen byte _miss = rowmiss(`X')
list nil name if _miss, noobs
drop if _miss
drop _miss
di as txt "  NIL nella tipologia: " as res _N
foreach v of local X {
    quietly summarize `v'
    gen double z_`v' = (`v' - r(mean))/r(sd)
    * valori estremi limitati a +-3 dev. std.: un solo NIL atipico non forma un gruppo da solo
    replace z_`v' = max(min(z_`v', 3), -3)
}
* k-medie: piu' ripartenze, si tiene la migliore
set seed $SEED
local best = .
forvalues s = 1/50 {
    capture drop g_try
    capture cluster drop g_try
    quietly cluster kmeans z_*, k(`K') name(g_try) start(random(`=$SEED + `s''))
    quietly gen double _w = 0
    foreach v of varlist z_* {
        quietly bysort g_try: egen double _m = mean(`v')
        quietly replace _w = _w + (`v' - _m)^2
        drop _m
    }
    quietly summarize _w
    local w = r(sum)
    drop _w
    if `w' < `best' {
        local best = `w'
        capture drop type
        gen byte type = g_try
    }
}
drop g_try
capture cluster drop g_try
* rinumera i gruppi per quota di 65+ crescente (etichette stabili)
bysort type: egen double _o = mean(sh_g65)
egen byte typ = group(_o)
drop type _o
rename typ type
label variable type "Tipo di NIL (k-medie sulla composizione 2014)"

di as txt _n "  Medie per tipo (2014):"
tabstat `X' pop27, by(type) stat(mean) format(%7.3f) save
preserve
collapse (mean) `X' pop27 (count) n_nil = nil, by(type)
export delimited using "$TAB/nil_typology_means.csv", replace
restore

* quanto i tipi spiegano le differenze tra NIL (R2 per variabile)
di as txt _n "  Quota della varianza tra NIL spiegata dai tipi:"
foreach v of local X {
    quietly regress `v' i.type
    di as txt "   " %-12s "`v'" as res %6.2f e(r2)
}
list type nil name, noobs sepby(type)
keep nil name type `X' z_*
save "$WORK/nil_typology.dta", replace
export delimited nil name type `X' using "$TAB/nil_typology.csv", replace

* mappa
capture which spmap
if _rc == 0 {
    capture confirm file "$WORK/nil_shp_sorted.dta"
    if _rc == 0 {
        preserve
        use "$WORK/xwa_nilnew_ids.dta", clear
        destring code, gen(nil)
        keep _ID nil
        merge 1:1 nil using "$WORK/nil_typology.dta", keepusing(type) keep(master match) nogen
        sort _ID
        capture noisily spmap type using "$WORK/nil_shp_sorted.dta", id(_ID) clmethod(unique) ///
            fcolor("140 110 180" "120 170 220" "110 180 130" "240 170 110" "200 90 50") ///
            ocolor(white ..) osize(vthin ..) ndfcolor(gs14) ndocolor(white) ///
            legend(position(5) size(small)) legtitle("Tipo di NIL (2014)") ///
            note("k-medie sulla composizione dei residenti; grigio chiaro: NIL con meno di $SMALL_NIL residenti.", size(vsmall))
        if _rc == 0 graph export "$FIG/nil_typology_map.png", replace width(2000)
        restore
    }
}
