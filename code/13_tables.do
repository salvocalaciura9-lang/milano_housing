*==============================================================================*
* 13_tables.do
* Tabella completa delle stime, tabella di sensibilita' e statistiche
* descrittive (conteggi, quote, variazioni in punti e in log sono tenuti
* distinti nelle etichette).
*
* Output: $TAB/results_all.xlsx/.csv, $TAB/sensitivity.csv,
*         $TAB/descriptives.xlsx/.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "13 - TABELLE" _n "{hline 78}"

*------------------------------------------------------------------------------*
* Stime
*------------------------------------------------------------------------------*
frame results: save "$WORK/results.dta", replace
use "$WORK/results.dta", clear
if _N == 0 {
    di as txt "  Nessuna stima salvata."
}
else {
    gen long id = _n
    gen str40 ic95 = "[" + strofreal(lb, "%9.3f") + "; " + strofreal(ub, "%9.3f") + "]"
    gen str40 ic95_boot = cond(missing(lb_boot), "", ///
        "[" + strofreal(lb_boot, "%9.3f") + "; " + strofreal(ub_boot, "%9.3f") + "]")
    gen byte ci_excl0 = (lb > 0 | ub < 0)
    gen byte is_main = ustrregexm(spec, "^principale") & !ustrregexm(spec, "\[(pop|area)\]")
    bysort model: egen double b_main = max(cond(is_main == 1, b, .))
    gen byte same_sign = (sign(b) == sign(b_main)) if !missing(b_main)
    sort id
    label variable ci_excl0  "IC 95% esclude lo zero"
    label variable same_sign "Stesso segno della specificazione principale"
    order id model spec coef b se ic95 p N p_boot ic95_boot same_sign ci_excl0 cmd note
    list model spec coef b ic95 N same_sign, noobs sepby(model) abbreviate(16) string(60)
    export excel using "$TAB/results_all.xlsx", firstrow(variables) replace
    export delimited using "$TAB/results_all.csv", replace

    * tabella di sensibilita': quante varianti confermano segno e precisione
    preserve
    keep if !missing(b_main)
    collapse (count) n_spec=b (sum) n_same=same_sign n_excl0=ci_excl0 (first) b_main, by(model)
    list, noobs abbreviate(16)
    export delimited using "$TAB/sensitivity.csv", replace
    restore
}

*------------------------------------------------------------------------------*
* Statistiche descrittive
*------------------------------------------------------------------------------*
capture frame drop desc
frame create desc str40 tabella str32 variabile str244 etichetta double N double media ///
    double sd double p25 double p50 double p75 double min double max

capture program drop descpost
program define descpost
    syntax varlist [if], Table(string)
    marksample touse, novarlist
    foreach v of local varlist {
        quietly summarize `v' if `touse', detail
        local lab : variable label `v'
        frame post desc ("`table'") ("`v'") ("`lab'") (r(N)) (r(mean)) (r(sd)) ///
            (r(p25)) (r(p50)) (r(p75)) (r(min)) (r(max))
    }
end

use "$WORK/outmig_nil.dta", clear
descpost r_pre r_post r_change pop2019 pct65_2019 d_minors_1923 d_a65_1923 d_foreign_1923 ///
    d_fam1_1923, table("NIL: uscite e composizione")

capture confirm file "$WORK/gentrif_nil.dta"
if !_rc {
    use "$WORK/gentrif_nil.dta", clear
    descpost G_social d_edu_std d_emp_std dI_common dI_eq dI_paper if valid_full == 1, ///
        table("NIL: gentrificazione (campione valido)")
}

use "$WORK/irpef_cap_year.dta", clear
foreach y in $Y0A $Y1 {
    descpost ybar_imp ybar_lav ncontrib nlow15 sh_low15 if year == `y', table("CAP: fiscale `y'")
}

use "$WORK/omi_zone_change.dta", clear
descpost R_mid_0 R_mid_1 dlnR P_mid_0 P_mid_1 dlnP, table("Zone OMI: $Y0 e $Y1")

capture confirm file "$WORK/cap_cross_main.dta"
if !_rc {
    use "$WORK/cap_cross_main.dta", clear
    local dv dlnAR dlnAR_base dlnAP AR AR_base AP covR_min
    capture confirm variable G_social_cap
    if !_rc local dv `dv' G_social_cap
    descpost `dv' if cover_ok == 1, table("CAP integrato ($Y1; variazioni $Y0A-$Y1)")
}

frame desc {
    list, noobs sepby(tabella) abbreviate(12)
    export excel using "$TAB/descriptives.xlsx", firstrow(variables) replace
    export delimited using "$TAB/descriptives.csv", replace
}
