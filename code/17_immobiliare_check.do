*==============================================================================*
* 17_immobiliare_check.do
* Validazione della misura di affitto: quotazioni OMI vs affitti RICHIESTI su
* Immobiliare.it, per le 32 macrozone di Immobiliare (31 abbinate ai NIL).
*
* Dati Immobiliare (data/raw/immobiliare_macrozone_ott2026.csv): letti a mano
* dalle pagine pubbliche "mercato immobiliare" (consultate il 22/11/2026):
* valore di ottobre 2026 e variazioni a 1, 3, 5 anni e da inizio serie (lug 2018).
* Da questi si ricavano i livelli:
*   lug 2018 = V / (1 + tutti),  ott 2021 = V / (1 + 5a),
*   ott 2023 = V / (1 + 3a),     ott 2025 = V / (1 + 1a)
* (le percentuali sono arrotondate allo 0,1%: errore trascurabile).
*
* OMI: abitazioni civili NORMALE, punto medio, SECONDO SEMESTRE (luglio-dicembre,
* allineato ai mesi di Immobiliare). Zona -> NIL con i pesi di superficie
* (xw_nil_omi_area.csv), NIL -> macrozona con data/auxdata/xw_immobiliare_macrozona_nil.csv,
* media ponderata per i residenti 2023 dei NIL.
*
* Confronti: variazioni log 2018-23 (lug 2018 -> ott 2023 vs 2018S2 -> 2023S2) e
* 2021-23; livelli 2023. Output: $TAB/immobiliare_vs_omi.csv, $FIG/immobiliare_vs_omi.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "17 - CONTROLLO: AFFITTI OMI VS IMMOBILIARE.IT" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw AUX:data/auxdata WORK:data/work TAB:output/tables FIG:output/figures {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
foreach f in "$RAW/immobiliare_macrozone_ott2026.csv" "$AUX/xw_immobiliare_macrozona_nil.csv" "$AUX/xw_nil_omi_area.csv" {
    capture confirm file "`f'"
    if _rc {
        di as error "  manca `f': 17 saltato"
        exit
    }
}

*--- 1. Immobiliare: livelli ricostruiti ------------------------------------*
import delimited using "$RAW/immobiliare_macrozone_ott2026.csv", clear varnames(1) encoding("utf-8")
gen double ia_2018 = affitto_ott2026/(1 + a_tutti/100)
gen double ia_2021 = affitto_ott2026/(1 + a_5a/100)
gen double ia_2023 = affitto_ott2026/(1 + a_3a/100)
gen double ia_2025 = affitto_ott2026/(1 + a_1a/100)
keep slug macrozona ia_*
tempfile imm
save `imm'

*--- 2. OMI al NIL (secondo semestre) ----------------------------------------*
use "$WORK/omi_civ_sem.dta", clear
keep if sem == 2 & inlist(anno, 2018, 2021, 2023)
keep zona anno R_mid
tempfile omi
save `omi'

import delimited using "$AUX/xw_nil_omi_area.csv", clear varnames(1)
keep nil zona w
replace zona = upper(ustrtrim(zona))
expand 3
bysort nil zona: gen int anno = cond(_n == 1, 2018, cond(_n == 2, 2021, 2023))
* (il 2025 e' escluso: la revisione 2024 delle zone D15/D30 rompe la serie)
merge m:1 zona anno using `omi', keep(master match) nogen
gen double num = w*R_mid
gen double den = w if !missing(R_mid)
collapse (sum) num den wtot=w, by(nil anno)
gen double R_nil = num/den if den > 0
gen double cov = den/wtot
keep nil anno R_nil cov
reshape wide R_nil cov, i(nil) j(anno)
tempfile omin
save `omin'

*--- 3. NIL -> macrozona (pesi: residenti 2023) ------------------------------*
use "$WORK/ds205_nil_year.dta", clear
keep if year == 2023
keep nil pop
tempfile p23
save `p23'

import delimited using "$AUX/xw_immobiliare_macrozona_nil.csv", clear varnames(1)
merge 1:1 nil using `omin', keep(master match) nogen
merge 1:1 nil using `p23', keep(master match) nogen
foreach y in 2018 2021 2023 {
    gen double d`y' = pop if !missing(R_nil`y') & cov`y' >= 0.8
    gen double n`y' = pop*R_nil`y' if !missing(d`y')
}
collapse (sum) n2018 n2021 n2023 d2018 d2021 d2023 pop (count) n_nil=nil, by(slug)
foreach y in 2018 2021 2023 {
    gen double omi_`y' = n`y'/d`y' if d`y' > 0
}
keep slug omi_* pop n_nil
merge 1:1 slug using `imm'
di as txt "  Macrozone senza NIL abbinati (_merge = 2):"
list slug if _merge == 2, noobs
keep if _merge == 3
drop _merge

*--- 4. Confronti -----------------------------------------------------------*
gen double d_imm_1823 = ln(ia_2023) - ln(ia_2018)
gen double d_omi_1823 = ln(omi_2023) - ln(omi_2018)
gen double d_imm_2123 = ln(ia_2023) - ln(ia_2021)
gen double d_omi_2123 = ln(omi_2023) - ln(omi_2021)
gen double ratio_2023 = ia_2023/omi_2023
label variable ratio_2023 "Affitto richiesto Immobiliare / quotazione OMI, 2023"

di as txt _n "  Livelli 2023 (EUR/m2/mese): Immobiliare vs OMI"
corr ia_2023 omi_2023
summarize ratio_2023, detail
di as txt _n "  Variazioni log: correlazione di Pearson e di Spearman"
foreach p in 1823 2123 {
    quietly corr d_imm_`p' d_omi_`p'
    local r = r(rho)
    local n = r(N)
    quietly spearman d_imm_`p' d_omi_`p'
    di as txt "   `p': Pearson " as res %5.2f `r' as txt "   Spearman " as res %5.2f r(rho) as txt "   N = `n'"
}
di as txt _n "  Media delle variazioni (tutte le macrozone):"
summarize d_imm_* d_omi_*
regress d_imm_1823 d_omi_1823, vce(robust)

order slug macrozona n_nil pop ia_2018 omi_2018 ia_2023 omi_2023 ratio_2023 d_imm_1823 d_omi_1823 d_imm_2123 d_omi_2123
export delimited using "$TAB/immobiliare_vs_omi.csv", replace

twoway (scatter d_imm_1823 d_omi_1823, mcolor("57 135 229") msize(small) ///
           mlabel(macrozona) mlabsize(tiny) mlabcolor(gs8)) ///
       (lfit d_imm_1823 d_omi_1823, lcolor("230 100 50")) ///
       (function y = x, range(d_omi_1823) lcolor(gs10) lpattern(dash)), ///
       xtitle("Variazione log quotazioni OMI, 2018-2023 (2o semestre)") ///
       ytitle("Var. log affitti richiesti Immobiliare, 2018-2023") ///
       title("Affitti: OMI e Immobiliare.it per macrozona", size(medsmall)) ///
       legend(order(2 "Retta OLS" 3 "Bisettrice") rows(1) size(small) position(6)) graphregion(color(white)) ///
       note("31 macrozone Immobiliare abbinate ai NIL; OMI pesato per residenti 2023.", size(vsmall))
graph export "$FIG/immobiliare_vs_omi.png", replace width(2400)
