*==============================================================================*
* 19d_m4_dose.do
* M4: diff-in-diff con esposizione continua (intensita' del trattamento)
*
* Idea. Nel modulo 19 un'area e' trattata (almeno il 20% servito di nuovo), di
* controllo (mai vicina alla M4) o esclusa (servita solo in parte). Qui
* l'intensita' del trattamento e' la quota dell'area servita di nuovo dalla M4
* (enew, da 0 a 1): entrano anche le aree servite solo in parte, che il modulo 19
* esclude, e la domanda diventa "le aree piu' servite hanno avuto esiti diversi?".
* Riferimento: Callaway, Goodman-Bacon e Sant'Anna (2024), diff-in-diff con
* trattamento continuo.
*
* Stimatore (versione per aperture scaglionate dello stimatore del modulo 19):
*   per ogni gruppo di apertura g e periodo t, sulle aree del gruppo g e sui
*   controlli (aree mai vicine alla M4, piu' aree non ancora trattate in t):
*       dY_i = Y_it - Y_i,g-1 = a(g,t) + b(g,t) * d_i + errore,
*   con d_i = quota servita di nuovo per le aree del gruppo g, 0 per i controlli.
*   b(g,t) = effetto di passare da 0 al 100% dell'area servita di nuovo.
*   b = media dei b(g,t) dopo l'apertura, pesata per il numero di aree del gruppo;
*   placebo = stessa media negli anni prima (da g-8 a g-2 periodi).
*   Ipotesi: trend paralleli per ogni livello di esposizione e risposta lineare
*   nell'esposizione ("strong parallel trends" in Callaway, Goodman-Bacon e
*   Sant'Anna, 2024).
* Gruppo di apertura di un'area esposta: la tratta che serve di nuovo la quota
*   maggiore della sua area.
* Aree escluse: vicine alla M4 ma gia' servite da altre linee (enew = 0, eany > 0).
* Inferenza: permutazione congiunta di (gruppo di apertura, esposizione) tra le
*   aree del campione.
*
* Input:  $WORK/m4_zone_panel.dta, m4_nil_panel.dta (modulo 19, raggio $M4_RADIUS m)
* Output: $TAB/m4_dose_results.csv, m4_dose_units.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19d - M4: ESPOSIZIONE CONTINUA" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$M4_PERMS" == "" global M4_PERMS 999
if "$M4_TLAST" == "" global M4_TLAST 2026     // ultimo semestre OMI (2026 = 2026S1)
foreach f in "$WORK/m4_zone_panel.dta" "$WORK/m4_nil_panel.dta" {
    capture confirm file "`f'"
    if _rc {
        di as error "  manca `f' (modulo 19): 19d saltato"
        exit
    }
}
set seed $SEED

*--- 0. Programmi --------------------------------------------------------------*
capture program drop csdose
program define csdose, rclass
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Dose(varname) ///
        Sample(varname) Step(real) Tmax(real) [Prewin(integer 8)]
    local y `varlist'
    tempvar yb dy inS dd md my cxy cxx sxy sxx
    quietly levelsof `cohort' if `cohort' > 0 & `sample' & `dose' > 0, local(G)
    local num 0
    local den 0
    local nump 0
    local denp 0
    foreach g of local G {
        local b = `g' - `step'
        quietly {
            capture drop `yb' `dy' `inS' `dd' `md' `my' `cxy' `cxx' `sxy' `sxx'
            bysort `unit': egen double `yb' = max(cond(abs(`time' - `b') < 1e-6, `y', .))
            gen double `dy' = `y' - `yb' if `sample'
            * aree del gruppo g con la loro esposizione; controlli con esposizione 0
            gen byte `inS' = `sample' & !missing(`dy') & ///
                ((abs(`cohort' - `g') < 1e-6 & `dose' > 0) | `dose' == 0 | ///
                 (`cohort' > max(`time', `b') + 1e-6 & `dose' > 0))
            gen double `dd' = cond(abs(`cohort' - `g') < 1e-6, `dose', 0) if `inS'
            bysort `time': egen double `md' = mean(cond(`inS', `dd', .))
            bysort `time': egen double `my' = mean(cond(`inS', `dy', .))
            gen double `cxy' = (`dd' - `md')*(`dy' - `my') if `inS'
            gen double `cxx' = (`dd' - `md')^2 if `inS'
            bysort `time': egen double `sxy' = total(`cxy')
            bysort `time': egen double `sxx' = total(`cxx')
            count if abs(`cohort' - `g') < 1e-6 & `dose' > 0 & abs(`time' - `b') < 1e-6 & !missing(`yb') & `sample'
            local ng = r(N)
            levelsof `time' if `time' <= `tmax' + 1e-6, local(T)
        }
        if `ng' == 0 continue
        foreach t of local T {
            quietly summarize `sxy' if abs(`time' - `t') < 1e-6, meanonly
            local a = r(mean)
            quietly summarize `sxx' if abs(`time' - `t') < 1e-6, meanonly
            if r(mean) <= 0 | missing(r(mean)) continue
            local a = `a'/r(mean)
            if missing(`a') continue
            if `t' >= `g' - 1e-6 {
                local num = `num' + `ng'*`a'
                local den = `den' + `ng'
            }
            if `t' <= `g' - 2*`step' + 1e-6 & `t' >= `g' - `prewin'*`step' - 1e-6 {
                local nump = `nump' + `ng'*`a'
                local denp = `denp' + `ng'
            }
        }
    }
    return scalar b = cond(`den' > 0, `num'/`den', .)
    return scalar pre = cond(`denp' > 0, `nump'/`denp', .)
end

capture mata: mata drop m4_perm2()
mata:
void m4_perm2(string scalar vars, string scalar sel, string scalar outs)
{
    real matrix X
    real colvector p
    X = st_data(., tokens(vars), sel)
    p = jumble(1::rows(X))
    st_store(., tokens(outs), sel, X[p, .])
}
end

capture program drop m4dose
program define m4dose
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Dose(varname) ///
        Sample(varname) Step(real) Tmax(real) Spec(string) Perms(integer) [Prewin(integer 8)]
    local y `varlist'
    csdose `y', unit(`unit') time(`time') cohort(`cohort') dose(`dose') sample(`sample') ///
        step(`step') tmax(`tmax') prewin(`prewin')
    local b = r(b)
    local pre = r(pre)
    tempvar first cf df cp dp
    quietly {
        bysort `unit' (`time'): gen byte `first' = _n == 1 & `sample'
        count if `first' & `dose' > 0
        local nD = r(N)
        count if `first' & `dose' == 0
        local nC = r(N)
        summarize `dose' if `first' & `dose' > 0
        local dbar = r(mean)
    }
    local ext 0
    local extp 0
    local ok 0
    forvalues j = 1/`perms' {
        quietly {
            capture drop `cf' `df' `cp' `dp'
            gen double `cf' = .
            gen double `df' = .
            mata: m4_perm2("`cohort' `dose'", "`first'", "`cf' `df'")
            bysort `unit': egen double `cp' = max(`cf')
            bysort `unit': egen double `dp' = max(`df')
        }
        csdose `y', unit(`unit') time(`time') cohort(`cp') dose(`dp') sample(`sample') ///
            step(`step') tmax(`tmax') prewin(`prewin')
        if !missing(r(b)) {
            local ++ok
            if abs(r(b)) >= abs(`b') - 1e-12 local ++ext
            if abs(r(pre)) >= abs(`pre') - 1e-12 local ++extp
        }
    }
    local p = (`ext' + 1)/(`ok' + 1)
    local pp = (`extp' + 1)/(`ok' + 1)
    frame post m4d ("`spec'") ("`y'") (`b') (`b'*`dbar') (`b'*0.2) (`p') (`pre') (`pp') (`nD') (`nC') (`dbar')
    di as txt "  -> " as res "`spec'" as txt " [`y']: effetto al 100% " as res %8.4f `b' ///
        as txt "  all'esposizione media (" %4.2f `dbar' ") " as res %8.4f `b'*`dbar' ///
        as txt "  p perm = " as res %5.3f `p' as txt "   placebo " as res %8.4f `pre' ///
        as txt " (p " %5.3f `pp' ")   esposte " `nD' "  controlli " `nC'
end

capture frame drop m4d
frame create m4d str80 spec str12 outcome double b double eff_mean double eff20 double p_perm ///
    double pre double p_perm_pre long nD long nC double dose_mean

* gruppo di apertura di un'area esposta: tratta con la quota servita di nuovo maggiore
capture program drop dosegroups
program define dosegroups
    args t1 t2 t3
    gen double dose = enew
    replace dose = 0 if eany == 0
    gen double cohort_d = .
    replace cohort_d = `t1' if dose > 0 & e1 >= e2 & e1 >= e3
    replace cohort_d = `t2' if dose > 0 & missing(cohort_d) & e2 >= e3
    replace cohort_d = `t3' if dose > 0 & missing(cohort_d)
    replace cohort_d = 0 if dose == 0 & eany == 0
    * esclusa: vicina alla M4 ma servita solo da altre linee
    gen byte s_dose = dose > 0 | eany == 0
    replace s_dose = 0 if missing(cohort_d)
end

*--- 1. Zone OMI: affitti e prezzi ------------------------------------------------*
di as txt _n "  {ul:Zone OMI, semestri}"
use "$WORK/m4_zone_panel.dta", clear
capture confirm variable enew
if _rc {
    di as error "  il pannello delle zone non ha enew: rieseguire il modulo 19"
    exit 459
}
dosegroups 2023 2023.5 2025
preserve
bysort zona: keep if _n == 1
gen str20 ruolo = cond(!s_dose, "esclusa", cond(dose == 0, "controllo", ///
    cond(cohort > 0 & !missing(cohort), "trattata nel modulo 19", "esposta in parte")))
tab ruolo
list zona cohort_d dose e1 e2 e3 eany ruolo if dose > 0, noobs sep(0)
keep zona ruolo cohort_d dose e1 e2 e3 eany enew
gen str4 livello = "zona"
tempfile uz
save `uz'
restore
m4dose lnR, unit(zid) time(t) cohort(cohort_d) dose(dose) sample(s_dose) step(0.5) tmax($M4_TLAST) ///
    spec("zone: affitti, esposizione continua") perms($M4_PERMS)
m4dose lnP, unit(zid) time(t) cohort(cohort_d) dose(dose) sample(s_dose) step(0.5) tmax($M4_TLAST) ///
    spec("zone: prezzi, esposizione continua") perms($M4_PERMS)

*--- 2. NIL: uscite e ingressi ------------------------------------------------------*
di as txt _n "  {ul:NIL, anni}"
use "$WORK/m4_nil_panel.dta", clear
dosegroups 2023 2024 2025
preserve
bysort nil: keep if _n == 1
gen str20 ruolo = cond(!s_dose, "escluso", cond(dose == 0, "controllo", ///
    cond(cohort > 0 & !missing(cohort), "trattato nel modulo 19", "esposto in parte")))
tab ruolo
tostring nil, gen(zona)
keep zona ruolo cohort_d dose e1 e2 e3 eany enew
gen str4 livello = "NIL"
append using `uz'
order livello zona ruolo cohort_d dose
export delimited using "$TAB/m4_dose_units.csv", replace
restore
local NP = max(199, floor($M4_PERMS/2))
foreach v in r_ac r_in {
    m4dose `v', unit(nil) time(t) cohort(cohort_d) dose(dose) sample(s_dose) step(1) tmax(2024) ///
        spec("NIL: esposizione continua") perms(`NP')
}

frame m4d {
    gen double eff_mean_pct = 100*(exp(eff_mean) - 1) if inlist(outcome, "lnR", "lnP")
    gen double eff20_pct    = 100*(exp(eff20) - 1)    if inlist(outcome, "lnR", "lnP")
    format b eff_mean eff20 pre %8.4f
    format p_perm p_perm_pre dose_mean %5.3f
    list, noobs sep(0) abbrev(10)
    export delimited using "$TAB/m4_dose_results.csv", replace
}
