*==============================================================================*
* 19b_m4_robustness.do
* M4: potenza del test e controlli di robustezza del diff-in-diff (modulo 19)
*
* A. Potenza. Con poche aree trattate un effetto "non significativo" puo' essere
*    solo un test poco potente. Dalla distribuzione delle permutazioni (le stime
*    ottenute assegnando le date di apertura ad aree a caso) si ricava:
*      c     = valore critico al 5%: 95-esimo percentile di |stima permutata|;
*              un effetto vero pari a c viene rilevato circa meta' delle volte;
*      MDE80 = effetto minimo rilevabile con potenza dell'80%: il piu' piccolo d
*              tale che |d + e| >= c per l'80% delle stime permutate e.
*    Ipotesi: l'effetto si somma all'esito ed e' uguale per tutte le aree trattate;
*    il rumore della stima e' quello delle permutazioni.
* B. Togliere un'area trattata alla volta (zone per gli affitti, NIL per le uscite):
*    il risultato non deve dipendere da una sola area.
* C. Definizione del trattamento: raggio di 800 e 1.000 m (invece di 500) e soglia
*    di esposizione del 10% e del 30% (invece del 20%). Si rilancia il modulo 19 in
*    versione ridotta (affitti, prezzi, uscite) con questi parametri.
*
* Input:  $WORK/m4_zone_panel.dta, m4_nil_panel.dta (modulo 19); code/m4_programs.do
* Output: $TAB/m4_power.csv, m4_loo.csv, m4_robustness.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19b - M4: POTENZA DEL TEST E ROBUSTEZZA" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$M4_RADIUS" == "" global M4_RADIUS 500   // bacino pedonale; 800 m nella versione iniziale, ora controllo (19b)
if "$M4_TREAT" == "" global M4_TREAT 0.20
if "$M4_PERMS" == "" global M4_PERMS 999
if "$M4_TLAST" == "" global M4_TLAST 2026     // ultimo semestre OMI (2026 = 2026S1)
foreach f in "$WORK/m4_zone_panel.dta" "$WORK/m4_nil_panel.dta" {
    capture confirm file "`f'"
    if _rc {
        di as error "  manca `f' (eseguire prima il modulo 19): 19b saltato"
        exit
    }
}
do "$CODE/m4_programs.do"
set seed $SEED

*--- A. Potenza del test -------------------------------------------------------*
capture program drop m4power
program define m4power
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) Perms(integer) Label(string)
    local y `varlist'
    csatt `y', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') tmax(`tmax')
    local att = r(att)
    tempvar first cpf cp
    quietly bysort `unit' (`time'): gen byte `first' = _n == 1 & `sample'
    capture frame drop pw
    frame create pw double e
    forvalues j = 1/`perms' {
        quietly {
            capture drop `cpf' `cp'
            gen double `cpf' = .
            mata: m4_perm("`cohort'", "`first'", "`cpf'")
            bysort `unit': egen double `cp' = max(`cpf')
        }
        csatt `y', unit(`unit') time(`time') cohort(`cp') sample(`sample') step(`step') tmax(`tmax')
        if !missing(r(att)) frame post pw (r(att))
    }
    frame pw {
        quietly count
        local n = r(N)
        mata: m4_mde("e")
    }
    frame post m4pw ("`label'") ("`y'") (`att') (r_c) (r_mde80) (r_sd) (`n')
    di as txt "  -> " as res "`label'" as txt " [`y']: stima " as res %8.4f `att' ///
        as txt "   valore critico 5% " as res %7.4f r_c as txt "   MDE80 " as res %7.4f r_mde80 ///
        as txt "   (permutazioni valide: `n')"
end

capture mata: mata drop m4_mde()
mata:
void m4_mde(string scalar v)
{
    real colvector e, a
    real scalar c, d, step, pw
    e = st_data(., v)
    a = sort(abs(e), 1)
    c = a[ceil(0.95*rows(a))]
    step = c/400
    d = 0
    pw = 0
    while (pw < 0.8 & d < 10*c) {
        d = d + step
        pw = mean((abs(d :+ e) :>= c))
    }
    st_numscalar("r_c", c)
    st_numscalar("r_mde80", d)
    st_numscalar("r_sd", sqrt(variance(e)))
}
end

capture frame drop m4pw
frame create m4pw str70 spec str12 outcome double att double crit5 double mde80 double sd_perm long nperm

di as txt _n "  {ul:A. Potenza del test (effetto minimo rilevabile)}"
use "$WORK/m4_zone_panel.dta", clear
m4power lnR, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax($M4_TLAST) ///
    perms($M4_PERMS) label("(1) affitti, controlli abbinati + non ancora trattate")
m4power lnR, unit(zid) time(t) cohort(cohort) sample(s_all) step(0.5) tmax($M4_TLAST) ///
    perms($M4_PERMS) label("(2) affitti, tutte le mai esposte + non ancora trattate")
m4power lnP, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax($M4_TLAST) ///
    perms($M4_PERMS) label("(4) prezzi, controlli abbinati")
use "$WORK/m4_nil_panel.dta", clear
local NP = max(199, floor($M4_PERMS/2))
m4power r_ac, unit(nil) time(t) cohort(cohort) sample(s_nil) step(1) tmax(2024) ///
    perms(`NP') label("(5) uscite, NIL mai esposti + non ancora trattati")
m4power r_ac, unit(nil) time(t) cohort(cohort) sample(s_nilm) step(1) tmax(2024) ///
    perms(`NP') label("(6) uscite, NIL abbinati + non ancora trattati")
frame m4pw {
    gen double att_pct   = 100*(exp(att) - 1)   if inlist(outcome, "lnR", "lnP")
    gen double crit5_pct = 100*(exp(crit5) - 1) if inlist(outcome, "lnR", "lnP")
    gen double mde80_pct = 100*(exp(mde80) - 1) if inlist(outcome, "lnR", "lnP")
    format att crit5 mde80 sd_perm %8.4f
    format att_pct crit5_pct mde80_pct %6.1f
    list, noobs sep(0) abbrev(10)
    export delimited using "$TAB/m4_power.csv", replace
}

*--- B. Togliere un'area trattata alla volta -----------------------------------*
capture frame drop m4cs
frame create m4cs str90 spec str16 outcome double att double p_perm double pre double p_perm_pre long nT long nC

di as txt _n "  {ul:B. Senza un'area trattata alla volta}"
use "$WORK/m4_zone_panel.dta", clear
quietly levelsof zona if cohort > 0 & !missing(cohort) & s_match, local(TZ) clean
foreach z of local TZ {
    tempvar s
    gen byte `s' = s_match & zona != "`z'"
    m4run lnR, unit(zid) time(t) cohort(cohort) sample(`s') step(0.5) tmax($M4_TLAST) ///
        spec("affitti (1) senza la zona `z'") perms($M4_PERMS)
    drop `s'
}
use "$WORK/m4_nil_panel.dta", clear
* NIL trattati con anni dopo l'apertura nei dati (aperture 2023 e 2024)
quietly levelsof nil if inlist(cohort, 2023, 2024) & s_nilm, local(TN)
foreach n of local TN {
    local nm
    capture quietly levelsof nilname if nil == `n', local(nm) clean
    tempvar s
    gen byte `s' = s_nilm & nil != `n'
    m4run r_ac, unit(nil) time(t) cohort(cohort) sample(`s') step(1) tmax(2024) ///
        spec("uscite (6) senza il NIL `n' `nm'") perms(`NP')
    drop `s'
}
frame m4cs: export delimited using "$TAB/m4_loo.csv", replace

*--- C. Raggio e soglia di esposizione -----------------------------------------*
di as txt _n "  {ul:C. Definizione del trattamento: raggio e soglia}"
local R0 $M4_RADIUS
local T0 $M4_TREAT
local P0 $M4_PERMS
global M4_LIGHT 1
global M4_PERMS 499
foreach v in "r800 800 0.20" "r1000 1000 0.20" "t10 500 0.10" "t30 500 0.30" {
    tokenize `v'
    global M4_TAG `1'
    global M4_RADIUS `2'
    global M4_TREAT `3'
    di as txt _n "  --- variante `1': raggio `2' m, soglia `3' ---"
    quietly do "$CODE/19_m4_did.do"
}
global M4_TAG
global M4_LIGHT 0
global M4_RADIUS `R0'
global M4_TREAT `T0'
global M4_PERMS `P0'

* potenza anche con raggio 800 m e 1.000 m (stessa procedura della sezione A)
di as txt _n "  {ul:Potenza del test con raggio diverso}"
frame m4pw: capture drop att_pct crit5_pct mde80_pct
foreach v in "r800|800 m" "r1000|1.000 m" {
    gettoken tag lab : v, parse("|")
    local lab = substr("`lab'", 2, .)
    capture confirm file "$WORK/m4_zone_panel_`tag'.dta"
    if _rc continue
    use "$WORK/m4_zone_panel_`tag'.dta", clear
    m4power lnR, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax($M4_TLAST) ///
        perms($M4_PERMS) label("(1) affitti, controlli abbinati, raggio `lab'")
    m4power lnP, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax($M4_TLAST) ///
        perms($M4_PERMS) label("(4) prezzi, controlli abbinati, raggio `lab'")
    use "$WORK/m4_nil_panel_`tag'.dta", clear
    m4power r_ac, unit(nil) time(t) cohort(cohort) sample(s_nilm) step(1) tmax(2024) ///
        perms(`NP') label("(6) uscite, NIL abbinati, raggio `lab'")
}
frame m4pw {
    capture drop att_pct crit5_pct mde80_pct
    gen double att_pct   = 100*(exp(att) - 1)   if inlist(outcome, "lnR", "lnP")
    gen double crit5_pct = 100*(exp(crit5) - 1) if inlist(outcome, "lnR", "lnP")
    gen double mde80_pct = 100*(exp(mde80) - 1) if inlist(outcome, "lnR", "lnP")
    format att_pct crit5_pct mde80_pct %6.1f
    list spec outcome att crit5 mde80 mde80_pct nperm, noobs sep(0) abbrev(10)
    export delimited using "$TAB/m4_power.csv", replace
}

* tabella riassuntiva: versione principale + varianti + senza un'area
tempfile acc
import delimited using "$TAB/m4_cs_results.csv", clear varnames(1) stringcols(1 2)
keep if regexm(spec, "^\((1|2|4|5|6)\)") & inlist(outcome, "lnR", "lnP", "r_ac")
gen str40 variante = "principale (500 m, 20%)"
save `acc'
foreach v in "r800|raggio 800 m" "r1000|raggio 1.000 m" "t10|soglia 10%" "t30|soglia 30%" {
    gettoken tag lab : v, parse("|")
    local lab = substr("`lab'", 2, .)
    capture confirm file "$TAB/m4_cs_results_`tag'.csv"
    if _rc continue
    import delimited using "$TAB/m4_cs_results_`tag'.csv", clear varnames(1) stringcols(1 2)
    keep if regexm(spec, "^\((1|2|4|5|6)\)") & inlist(outcome, "lnR", "lnP", "r_ac")
    gen str40 variante = "`lab'"
    append using `acc'
    save `acc', replace
}
import delimited using "$TAB/m4_loo.csv", clear varnames(1) stringcols(1 2)
gen str40 variante = "senza un'area trattata"
append using `acc'
gen double att_pct = 100*(exp(att) - 1) if inlist(outcome, "lnR", "lnP")
order variante spec outcome att att_pct p_perm pre p_perm_pre nt nc
format att pre %8.4f
format att_pct %6.1f
format p_perm p_perm_pre %5.3f
sort outcome variante spec
di as txt _n "  Robustezza: effetto, p di permutazione, placebo, numero di trattate e controlli"
list variante spec outcome att p_perm pre p_perm_pre nt nc, noobs sepby(outcome) abbrev(10)
export delimited using "$TAB/m4_robustness.csv", replace
