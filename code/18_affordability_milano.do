*==============================================================================*
* 18_affordability_milano.do
* Evoluzione dell'affordability degli affitti a Milano per il "cittadino tipico"
*
* Indice principale (dal 2007):
*   A_it = 12 x S x affitto OMI_it (EUR/m2/mese, punto medio) / reddito NETTO mediano_t
*   quartiere "fuori portata" se A_it > 0,40: soglia OCSE/Eurostat di sovraccarico
*   (OECD Affordable Housing Database, HC1.2.3: affitto o mutuo > 40% del reddito
*   disponibile). Il netto mediano si calcola con il programma netinc
*   (netinc_program.do), detrazioni da lavoro dipendente; altri scenari, controllo
*   con le imposte vere e scenario calibrato nel modulo 18b.
*   La prima versione usava il 30% del reddito lordo (regola HUD): resta come
*   controllo (A60g, 2004-2024).
*
* Scenari (S = superficie, reddito al denominatore):
*   A60  : 60 m2, un reddito netto mediano     (indice principale, soglia 40%)
*   A40  : 40 m2, un reddito netto mediano     (single in un monolocale)
*   A60d : 60 m2, due redditi netti mediani    (coppia con due redditi)
*   A60g : 60 m2, reddito LORDO mediano, soglia 30% (controllo, regola HUD)
*
* Dati
*   - Reddito: ds531 (Comune di Milano), contribuenti per classe di reddito
*     complessivo, anno d'imposta 2008-2024; per il 2004-2007 i file MEF
*     "redditi e principali variabili IRPEF su base comunale" (stesse classi).
*     La mediana si stima per
*     interpolazione lineare dentro la classe che contiene il 50% dei contribuenti
*     (ipotesi: contribuenti distribuiti uniformemente nella classe).
*     Per confronto si calcola anche il reddito medio (ammontare / contribuenti).
*   - Affitti: OMI DS1996, abitazioni civili stato normale, punto medio, per
*     zona e semestre. La zonizzazione OMI cambia nel 2014 (55 -> 38 zone) e nel
*     secondo semestre 2024 (D15 e D30 divise): ogni semestre si collega alla
*     griglia con la zonizzazione in vigore (zona11 fino al 2013, zona 2014S2-2024S1,
*     zona25 dal 2024S2; il 2014S1, di transizione, e' escluso) e si porta sui NIL
*     e sulle zone OMI 2021 con pesi di
*     superficie (punti della griglia di ~28 m, modulo 10a).
*   - Residenti: DS205 (2011-2024); per il 2004-2010 si usano i residenti 2011.
*   - Esclusi i NIL con meno di $SMALL_NIL residenti nel 2019 (parchi, scali).
*
* Output
*   $WORK/milano_income.dta         reddito mediano lordo (2004-2024) e netto (2007-2024), medio
*   $WORK/milano_income_classes.dta classi di reddito per anno (per il modulo 18b)
*   $WORK/omi_nil_year_long.dta     affitto OMI per NIL e anno, 2004-2025
*   $WORK/omi_zone21_year.dta       affitto OMI per zona (zonizzazione 2021), 2014-2025
*   $WORK/omi_zone21_sem.dta, omi_nil_sem.dta  affitti e prezzi per semestre (per il modulo 19)
*   $WORK/aff_nil_year.dta          indice per NIL e anno
*   $TAB/aff_city_year.csv          per anno: reddito, quota di NIL e di residenti oltre la soglia
*   $TAB/aff_nil_year.csv           pannello NIL x anno
*   $FIG/aff_share_above40.png      quota di residenti in NIL oltre la soglia, per scenario
*   $FIG/aff_map_A60_2008.png, aff_map_A60_2024.png  mappe dell'indice principale
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "18 - AFFORDABILITY PER IL CITTADINO TIPICO (REDDITO MEDIANO DI MILANO)" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SMALL_NIL" == "" global SMALL_NIL 500
local THR   0.40      // soglia di affordability sul reddito netto (OCSE)
local THRG  0.30      // soglia sul reddito lordo (controllo, regola HUD)
local COV   0.80      // copertura minima di un NIL o di una zona con zone OMI quotate

*--- 1. Reddito mediano di Milano (ds531) ----------------------------------*
import delimited using "$RAW/ds531_classi_reddito_complessivo.csv", clear ///
    delimiter(";") varnames(1) encoding("utf-8") stringcols(2)
rename (anno classidiredditocomplessivoineuro frequenzapersonefisiche ammontareineuro) ///
       (year cls n amt)
replace cls = ustrtrim(cls)
gen double lo = .
gen double hi = .
replace lo = -1e9  if strpos(cls, "minore")
replace hi = 0     if strpos(cls, "minore")
replace lo = 0     if cls == "da 0 a 10.000"
replace hi = 10000 if cls == "da 0 a 10.000"
replace lo = 10000 if cls == "da 10.000 a 15.000"
replace hi = 15000 if cls == "da 10.000 a 15.000"
replace lo = 15000 if cls == "da 15.000 a 26.000"
replace hi = 26000 if cls == "da 15.000 a 26.000"
replace lo = 26000 if cls == "da 26.000 a 55.000"
replace hi = 55000 if cls == "da 26.000 a 55.000"
replace lo = 55000 if cls == "da 55.000 a 75.000"
replace hi = 75000 if cls == "da 55.000 a 75.000"
replace lo = 75000 if cls == "da 75.000 a 120.000"
replace hi = 120000 if cls == "da 75.000 a 120.000"
replace lo = 120000 if strpos(cls, "oltre")
replace hi = .      if strpos(cls, "oltre")
count if missing(lo)
if r(N) {
    di as error "  classi di reddito non riconosciute:"
    list year cls if missing(lo)
    error 459
}
keep year lo hi n amt
tempfile ds531
save `ds531'

* 2004-2007: file MEF "redditi e principali variabili IRPEF su base comunale"
* (stesse classi di reddito complessivo del ds531)
clear
tempfile mef
save `mef', emptyok
forvalues y = 2004/2007 {
    import delimited using "$RAW/redditi_e_principali_variabili_irpef_su_base_comunale_csv_`y'.csv", ///
        clear delimiter(";") varnames(1) encoding("utf-8") stringcols(_all)
    rename (redditi valori) (key val)
    keep if strpos(key, "Reddito complessivo")
    gen str4 what = cond(strpos(key, "Frequenza"), "n", "amt")
    gen double lo = .
    gen double hi = .
    replace lo = -1e9 if strpos(key, "minore o uguale")
    replace hi = 0    if strpos(key, "minore o uguale")
    replace lo = real(ustrregexs(1)) if ustrregexm(key, "da ([0-9]+) a ([0-9]+) euro")
    replace hi = real(ustrregexs(2)) if ustrregexm(key, "da ([0-9]+) a ([0-9]+) euro")
    replace lo = 120000 if strpos(key, "oltre 120000")
    assert !missing(lo)
    gen double v = real(val)
    keep lo hi what v
    reshape wide v, i(lo hi) j(what) string
    rename (vn vamt) (n amt)
    gen int year = `y'
    append using `mef'
    save `mef', replace
}
append using `ds531'
* classi vuote (nel 2006-2007 nessun contribuente con reddito <= 0)
drop if n == 0
sort year lo
by year: gen double cum = sum(n)
by year: egen double ntot = total(n)
by year: egen double atot = total(amt)
gen double cum0 = cum - n
gen byte inmed = cum0 < ntot/2 & cum >= ntot/2
gen double med = lo + (ntot/2 - cum0)/n*(hi - lo) if inmed
* controllo: la mediana non deve cadere nella classe aperta (oltre 120.000)
assert !(inmed & missing(hi))
keep year lo hi n amt cum ntot atot cum0 inmed med
save "$WORK/milano_income_classes.dta", replace
* netto mediano: netto ai confini delle classi (il netto cresce con il lordo),
* interpolazione sulla classe netta che contiene il contribuente mediano
do "$CODE/netinc_program.do"
netinc lo, year(year) type(dip) gen(nlo)
netinc hi, year(year) type(dip) gen(nhi)
replace nlo = lo if lo < 0 & year >= 2007
gen double med_net = nlo + (ntot/2 - cum0)/n*(nhi - nlo) if inmed
collapse (max) y_med = med y_med_net = med_net (first) n_contr = ntot amt_tot = atot, by(year)
gen double y_mean = amt_tot/n_contr
label variable y_med     "Reddito complessivo (lordo) mediano dei contribuenti, Milano (EUR)"
label variable y_med_net "Reddito netto mediano, detrazioni da lavoro dipendente (EUR)"
label variable y_mean    "Reddito complessivo medio dei contribuenti, Milano (EUR)"
format y_med y_med_net y_mean %9.0fc
di as txt _n "  Reddito dei contribuenti milanesi (anno d'imposta):"
list year n_contr y_med y_med_net y_mean, noobs sep(0)
keep year y_med y_med_net y_mean n_contr
save "$WORK/milano_income.dta", replace

*--- 2. Affitti OMI dai semestri alle geografie di arrivo ------------------*
* zonizzazione in vigore in ogni semestre
use "$WORK/omi_civ_sem.dta", clear
keep anno sem zona R_mid P_mid
bysort anno sem: egen byte old = max(zona == "B01")
bysort anno sem: egen byte z25 = max(inlist(zona, "D37", "D38", "D39", "D40"))
gen byte scheme = cond(old, 11, cond(z25, 25, 21))
drop old z25
* il primo semestre 2014 e' di transizione: meta' delle zone ha ancora i codici
* vecchi (B02-B06, C01-C09, D01-D09) senza poligoni corrispondenti; la
* zonizzazione 2021 vale dal secondo semestre 2014. Il 2014 usa solo 2014S2.
drop if anno == 2014 & sem == 1
rename zona z
tempfile sem
save `sem'

* pesi: punti della griglia per (area di arrivo, zonizzazione, zona)
capture program drop omi_weights
program define omi_weights
    args target out
    use "$WORK/xwa_grid.dta", clear
    if "`target'" == "nil" keep if !missing(nil)
    if "`target'" == "zona" keep if zona != ""
    rename zona zona21
    tempfile g
    save `g'
    bysort `=cond("`target'"=="zona","zona21","nil")': gen long tot = _N
    tempfile gt
    save `gt'
    clear
    tempfile acc
    local first 1
    foreach s in 11 21 25 {
        use `gt', clear
        local tv = cond("`target'" == "zona", "zona21", "nil")
        gen str3 z = zona`s'
        contract `tv' z tot, freq(npt)
        gen int scheme = `s'
        if `first' == 0 append using `acc'
        save `acc', replace
        local first 0
    }
    if "`target'" == "zona" rename zona21 zona
    save `out', replace
end

foreach T in nil zona {
    tempfile w_`T'
    omi_weights `T' `w_`T''
    use `sem', clear
    joinby scheme z using `w_`T''
    local tv = cond("`T'" == "zona", "zona", "nil")
    gen double num = npt*R_mid
    gen double den = npt if !missing(R_mid)
    gen double numP = npt*P_mid
    gen double denP = npt if !missing(P_mid)
    collapse (sum) num den numP denP (first) tot, by(`tv' anno sem)
    gen double R_sem = num/den if den > 0
    gen double P_sem = numP/denP if denP > 0
    gen double cov = den/tot
    replace R_sem = . if cov < `COV'
    replace P_sem = . if denP/tot < `COV'
    * versione semestrale (per il diff-in-diff del modulo 19)
    preserve
    rename (anno R_sem P_sem) (year R P)
    label variable R "Affitto OMI, punto medio (EUR/m2 lordo/mese)"
    label variable P "Compravendita OMI, punto medio (EUR/m2 lordo)"
    if "`T'" == "zona" {
        keep if year >= 2014
        save "$WORK/omi_zone21_sem.dta", replace
    }
    if "`T'" == "nil" save "$WORK/omi_nil_sem.dta", replace
    restore
    drop P_sem numP denP
    * media annua dei semestri disponibili
    collapse (mean) R = R_sem (min) cov, by(`tv' anno)
    rename anno year
    label variable R "Affitto OMI, punto medio (EUR/m2 lordo/mese), media dei semestri"
    label variable cov "Copertura minima con zone OMI quotate"
    if "`T'" == "nil" save "$WORK/omi_nil_year_long.dta", replace
    if "`T'" == "zona" {
        * la zonizzazione 2021 e' coerente solo dal 2014
        keep if year >= 2014
        save "$WORK/omi_zone21_year.dta", replace
    }
}

*--- 3. Indice per NIL e anno ----------------------------------------------*
use "$WORK/ds205_nil_year.dta", clear
keep nil year pop name
tempfile pop
save `pop'
keep if year == 2019
keep nil pop
rename pop pop2019
tempfile p19
save `p19'
use `pop', clear
keep if year == 2011
keep nil pop
rename pop pop2011
tempfile p11
save `p11'

use "$WORK/omi_nil_year_long.dta", clear
keep if inrange(year, 2004, 2024)
merge m:1 year using "$WORK/milano_income.dta", keep(match) nogen
merge 1:1 nil year using `pop', keep(master match) nogen
merge m:1 nil using `p11', keep(master match) nogen
merge m:1 nil using `p19', keep(master match) nogen
replace pop = pop2011 if year < 2011
bysort nil (name): replace name = name[_N]
drop if pop2019 < $SMALL_NIL
* indice principale sul netto (dal 2007), controllo sul lordo (dal 2004)
gen double A60  = 12*60*R/y_med_net
gen double A40  = 12*40*R/y_med_net
gen double A60d = 12*60*R/(2*y_med_net)
gen double A60g = 12*60*R/y_med
label variable A60  "Affitto 60 m2 / reddito netto mediano (soglia 40%)"
label variable A40  "Affitto 40 m2 / reddito netto mediano (soglia 40%)"
label variable A60d "Affitto 60 m2 / due redditi netti mediani (soglia 40%)"
label variable A60g "Affitto 60 m2 / reddito lordo mediano (soglia 30%, controllo)"
foreach a in A60 A40 A60d {
    gen byte off_`a' = `a' > `THR' if !missing(`a')
}
gen byte off_A60g = A60g > `THRG' if !missing(A60g)
* pannello bilanciato: NIL con l'affitto in tutti gli anni 2004-2024. Le quote
* annuali si calcolano solo su questi, cosi' non cambiano per effetto dei NIL
* che entrano o escono (nel 2014 la nuova zonizzazione OMI lascia alcune zone
* agricole senza quotazione)
bysort nil: egen byte nyrs = count(A60g)
quietly summarize year
gen byte balanced = nyrs == r(max) - r(min) + 1
drop nyrs
label variable balanced "NIL osservato in tutti gli anni 2004-2024"
order nil name year pop R y_med_net y_med A60 A40 A60d A60g
save "$WORK/aff_nil_year.dta", replace
export delimited using "$TAB/aff_nil_year.csv", replace

quietly levelsof nil if !missing(A60g)
local nall = r(r)
quietly levelsof nil if balanced
di as txt _n "  NIL con almeno un anno: " as res `nall' as txt "; nel pannello bilanciato: " as res r(r) ///
    as txt " (esclusi i NIL con meno di $SMALL_NIL residenti)"
di as txt "  Attenzione: fino al 2013 gli affitti usano la zonizzazione OMI precedente;" ///
    _n "  il confronto tra 2013 e 2014 risente del cambio dei confini delle zone."

*--- 4. Sintesi per anno (pannello bilanciato) ------------------------------*
preserve
keep if balanced
foreach a in A60 A40 A60d A60g {
    gen double pop_off_`a' = pop*off_`a'
    gen double pop_ok_`a'  = pop if !missing(`a')
}
collapse (mean) y_med_net y_med sh_nil_A60 = off_A60 sh_nil_A40 = off_A40 sh_nil_A60d = off_A60d ///
         sh_nil_A60g = off_A60g (median) A60_median = A60 A60g_median = A60g ///
         (min) A60_min = A60 (max) A60_max = A60 ///
         (sum) pop_off_* pop_ok_* (count) n_nil = A60g, by(year)
foreach a in A60 A40 A60d A60g {
    gen double sh_pop_`a' = pop_off_`a'/pop_ok_`a' if pop_ok_`a' > 0
}
drop pop_off_* pop_ok_*
label variable sh_pop_A60  "Quota di residenti in NIL oltre il 40% del netto (60 m2, un reddito)"
label variable sh_pop_A60g "Quota di residenti in NIL oltre il 30% del lordo (controllo)"
di as txt _n "  Quota di residenti che vive in NIL oltre il 40% del reddito netto mediano:"
list year y_med_net A60_median sh_pop_A40 sh_pop_A60 sh_pop_A60d sh_pop_A60g, noobs sep(0) abbrev(12)
export delimited using "$TAB/aff_city_year.csv", replace

twoway (connected sh_pop_A60  year, lcolor("37 106 191") mcolor("37 106 191") msize(small)) ///
       (connected sh_pop_A40  year, lcolor(gs7) mcolor(gs7) msize(small) lpattern(dash)) ///
       (connected sh_pop_A60d year, lcolor(gs11) mcolor(gs11) msize(small) lpattern(shortdash)) ///
       (line sh_pop_A60g year, lcolor("200 90 50%60") lpattern(longdash)), ///
       ylabel(0(.2)1, format(%3.1f)) xlabel(2004(2)2024) ///
       ytitle("Quota di residenti in NIL oltre la soglia") xtitle("") ///
       title("Quartieri fuori portata per chi ha il reddito mediano di Milano", size(medsmall)) ///
       legend(order(1 "60 m2, un reddito" 2 "40 m2, un reddito" 3 "60 m2, due redditi" ///
              4 "controllo: 30% del lordo") rows(2) size(small) position(6)) ///
       graphregion(color(white)) ///
       note("Affitto OMI (punto medio, abitazioni civili) / reddito netto mediano dei contribuenti milanesi; soglia 40% (OCSE)." ///
            "Netto stimato da ds531 con IRPEF, addizionali e bonus (detrazioni da lavoro dipendente), dal 2007.", size(vsmall))
graph export "$FIG/aff_share_above40.png", replace width(2400)
restore

*--- 5. Mappe dell'indice principale, 2008 e 2024 ---------------------------*
capture which spmap
if _rc == 0 {
    preserve
    use "$WORK/xwa_nilnew_ids.dta", clear
    destring code, gen(nil)
    keep _ID nil
    tempfile ids
    save `ids'
    * spmap vuole il file delle coordinate ordinato per _ID
    use "$WORK/xwa_nilnew_shp.dta", clear
    sort _ID shape_order
    save "$WORK/nil_shp_sorted.dta", replace
    restore
    foreach y in 2008 2024 {
        preserve
        keep if year == `y'
        keep nil A60
        merge 1:1 nil using `ids', keep(using match) nogen
        sort _ID
        capture noisily spmap A60 using "$WORK/nil_shp_sorted.dta", id(_ID) ///
            clmethod(custom) clbreaks(0 .3 .4 .5 .6 .8 2) ///
            fcolor("222 235 247" "198 219 239" "158 202 225" "107 174 214" "49 130 189" "8 81 156") ///
            ocolor(white ..) osize(vthin ..) ndfcolor(gs14) ndocolor(white) ///
            legend(position(5) size(small)) legtitle("Affitto 60 m2 / reddito netto mediano") ///
            title("`y'", size(medsmall)) ///
            note("Prime due classi: sotto la soglia del 40%. Grigio: NIL esclusi o senza copertura OMI.", size(vsmall))
        if _rc == 0 graph export "$FIG/aff_map_A60_`y'.png", replace width(2000)
        restore
    }
}
