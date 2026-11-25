*==============================================================================*
* 19c_m4_cantieri.do
* M4: anticipazione. Trattamento dall'inizio dei cantieri invece che dall'apertura
*
* Domanda: i residenti dei NIL serviti dalla M4 reagiscono gia' durante i lavori
* (disagio dei cantieri, aspettative), anni prima dell'apertura?
*
* Date di inizio dei cantieri (Wikipedia, voce "Linea M4", che cita Corriere della
* Sera e Comune di Milano; da verificare sulle fonti originali):
*   stazioni Linate Aeroporto, Repetti, Stazione Forlanini   19/07/2012
*   lavori preliminari Forlanini FS - Tricolore              19/01/2015
*   tratta ovest San Cristoforo - Coni Zugna                 01/02/2015
*   tratta centrale Coni Zugna - Tricolore                   02/11/2015
* Regola (come per le aperture nel modulo 19): coorte = primo anno intero dopo
* l'inizio dei lavori -> 2013 per le tre stazioni est, 2016 per tutte le altre.
*
* Esposizione: stessa definizione del modulo 19 (punti entro $M4_RADIUS m da una
* stazione M4 e oltre $M4_RADIUS m da altre linee; NIL trattato se almeno $M4_TREAT
* della sua area e' servita di nuovo da stazioni del gruppo).
*
* Solo NIL e solo esiti demografici: per gli affitti il cambio delle zone OMI nel
* 2014 rende impossibile confrontare prima e dopo il 2012-2015 (modulo 18).
* Esiti disponibili dal 2008 (ds27: migrazione netta per coorte, composizione,
* residenti) o dal 2012 (DS205: uscite e ingressi, che richiedono i residenti
* dell'anno precedente). Per la coorte 2013 le uscite non hanno anni placebo.
*
* Due finestre: (a) solo lavori, anni fino al 2021 (prima di qualsiasi apertura);
* (b) tutto il periodo fino al 2024 (lavori + apertura).
*
* Input:  $WORK/m4_nil_panel.dta (modulo 19), $WORK/xwa_grid.dta, ds535
* Output: $TAB/m4_cantieri_results.csv, m4_cantieri_groups.csv, m4_cantieri_event.csv,
*         $FIG/m4_cantieri_event.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19c - M4: ANTICIPAZIONE, TRATTAMENTO DALL'INIZIO DEI CANTIERI" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$M4_RADIUS" == "" global M4_RADIUS 800
if "$M4_TREAT" == "" global M4_TREAT 0.20
if "$M4_PERMS" == "" global M4_PERMS 999
capture confirm file "$WORK/m4_nil_panel.dta"
if _rc {
    di as error "  manca m4_nil_panel.dta (modulo 19): 19c saltato"
    exit
}
do "$CODE/m4_programs.do"
set seed $SEED

*--- 1. Esposizione ai due gruppi di cantieri ------------------------------------*
import delimited using "$RAW/ds535_tpl_metrofermate.csv", clear delimiter(";") ///
    varnames(1) encoding("utf-8") stringcols(_all)
rename (long_x_4326 lat_y_4326) (lon lat)
destring lon lat, replace
replace nome = ustrupper(ustrtrim(nome))
replace linee = subinstr(linee, " ", "", .)
gen byte m4 = strpos("," + linee + "," , ",4,") > 0
gen byte other = ustrregexm(linee, "[1235]")
* gruppo A: cantieri dal luglio 2012; gruppo B: cantieri nel 2015
gen byte grp = .
replace grp = 1 if m4 & inlist(nome, "LINATE AEROPORTO", "REPETTI", "STAZIONE FORLANINI")
replace grp = 2 if m4 & missing(grp)
keep if m4 | other
local n = _N
forvalues i = 1/`n' {
    local x`i' = lon[`i']
    local y`i' = lat[`i']
    local m4`i' = m4[`i']
    local ot`i' = other[`i']
    local gr`i' = grp[`i']
}
use "$WORK/xwa_grid.dta", clear
keep pid lon lat nil
keep if !missing(nil)
local R = 6371000
local k = _pi/180
foreach v in d1 d2 d4 doth {
    gen double `v' = .
}
forvalues i = 1/`n' {
    tempvar dd
    quietly gen double `dd' = 2*`R'*asin(sqrt(sin((lat - `y`i'')*`k'/2)^2 + ///
        cos(lat*`k')*cos(`y`i''*`k')*sin((lon - `x`i'')*`k'/2)^2))
    if `ot`i'' quietly replace doth = min(doth, `dd')
    if `m4`i'' {
        quietly replace d4 = min(d4, `dd')
        quietly replace d`gr`i'' = min(d`gr`i'', `dd')
    }
    drop `dd'
}
local r $M4_RADIUS
gen byte eA = d1 <= `r' & doth > `r'
gen byte eB = d2 <= `r' & doth > `r'
gen byte eany = d4 <= `r'
collapse (mean) eA eB eany, by(nil)
gen double cohort_c = .
replace cohort_c = 2016 if eB >= $M4_TREAT
replace cohort_c = 2013 if eA >= $M4_TREAT
replace cohort_c = 0 if eany == 0
label variable cohort_c "Primo anno intero dopo l'inizio dei cantieri (0 = mai esposto)"
tempfile cg
save `cg'

*--- 2. Pannello dei NIL e gruppi ---------------------------------------------------*
use "$WORK/m4_nil_panel.dta", clear
merge m:1 nil using `cg', keep(master match) keepusing(cohort_c eA eB) nogen
gen byte s_c  = !missing(cohort_c)
gen byte s_cm = (cohort_c > 0 & !missing(cohort_c)) | (matchedn == 1 & cohort_c == 0)
preserve
bysort nil: keep if _n == 1
capture confirm variable nilname
local nm = cond(_rc == 0, "nilname", "")
gen str30 ruolo = cond(missing(cohort_c), "escluso", cond(cohort_c == 0, ///
    cond(matchedn, "mai esposto (abbinato)", "mai esposto"), "cantieri, coorte " + string(cohort_c)))
tab ruolo
list nil `nm' cohort_c cohort eA eB if cohort_c > 0 & !missing(cohort_c), noobs sep(0)
export delimited nil `nm' ruolo cohort_c cohort eA eB if !missing(cohort_c) ///
    using "$TAB/m4_cantieri_groups.csv", replace
restore

*--- 3. Stime --------------------------------------------------------------------------*
capture frame drop m4cs
frame create m4cs str90 spec str16 outcome double att double p_perm double pre double p_perm_pre long nT long nC
local NP = max(199, floor($M4_PERMS/2))
local YC "r_ac r_in nm_c0009 nm_c2029 nm_c3039 sh_g2539 sh_for27 lnpop"
foreach v of local YC {
    capture confirm variable `v'
    if _rc continue
    m4run `v', unit(nil) time(t) cohort(cohort_c) sample(s_cm) step(1) tmax(2021) prewin(5) ///
        spec("(a) solo lavori (fino al 2021), abbinati") perms(`NP') esframe(esc_`v')
    m4run `v', unit(nil) time(t) cohort(cohort_c) sample(s_cm) step(1) tmax(2024) prewin(5) ///
        spec("(b) lavori + apertura (fino al 2024), abbinati") perms(`NP')
    m4run `v', unit(nil) time(t) cohort(cohort_c) sample(s_c) step(1) tmax(2021) prewin(5) ///
        spec("(c) solo lavori (fino al 2021), tutti i mai esposti") perms(`NP')
}
frame m4cs: export delimited using "$TAB/m4_cantieri_results.csv", replace

*--- 4. Event study: anni dall'inizio dei cantieri --------------------------------------*
tempfile ev
local first 1
foreach v in r_ac nm_c2029 nm_c0009 lnpop {
    capture frame esc_`v': count
    if _rc continue
    frame esc_`v' {
        gen double e = t - g
        collapse (mean) att [aw = nT], by(e)
        gen str12 outcome = "`v'"
        if `first' == 0 append using `ev'
        save `ev', replace
    }
    local first 0
}
preserve
use `ev', clear
sort outcome e
export delimited using "$TAB/m4_cantieri_event.csv", replace
* nel grafico solo gli anni in cui contribuiscono entrambe le coorti: oltre il
* quinto anno resta solo la coorte 2013 (2 NIL piccoli) e le stime sono rumore
keep if inrange(e, -8, 5)
twoway (connected att e if outcome == "r_ac", lcolor("37 106 191") mcolor("37 106 191") msize(small)) ///
       (connected att e if outcome == "nm_c2029", lcolor("200 90 50") mcolor("200 90 50") msize(small) lpattern(dash)), ///
    yline(0, lcolor(gs8)) xline(-0.5, lcolor(gs10) lpattern(dash)) ///
    xtitle("Anni dal primo anno intero di cantieri") ytitle("Differenza NIL esposti - controlli (per 1.000)") ///
    title("M4: residenti durante i cantieri, NIL esposti vs controlli abbinati", size(medsmall)) ///
    legend(order(1 "uscite verso altri comuni" 2 "migrazione netta 20-29 anni") rows(1) size(small) position(6)) ///
    graphregion(color(white)) ///
    note("Callaway e Sant'Anna, base = anno prima dei cantieri. Coorti 2013 (Linate-Forlanini) e 2016 (resto della linea); anni fino al 2021." ///
         "Mostrati gli anni da -8 a +5, in cui contribuiscono entrambe le coorti.", size(vsmall))
graph export "$FIG/m4_cantieri_event.png", replace width(2400)
restore
