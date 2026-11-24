*==============================================================================*
* 07b_nil_vigenti.do
* Porta le misure dell'indice (calcolate sui NIL PGT 2012 del paper) sulla
* geografia dei NIL VIGENTI usata dal DS205 (popolazione e uscite).
* Prima i codici venivano uniti per numero: per i NIL ridisegnati (es. ID 73
* Cascina Triulza-Expo -> Cascina Merlata, ID 74 Sacco -> Roserio) lo stesso
* numero indica aree diverse.
*
* Metodo: media ponderata con i pesi di superficie del raccordo
*   x_nuovo = sum_vecchi w * x_vecchio / sum_vecchi w   (solo NIL vecchi con x valido)
* Il valore resta mancante se i NIL vecchi con dato valido coprono meno di
* XW_NILCOV della superficie del NIL vigente. Gli zeri sospetti dell'indice
* (reddito 0, prezzo 0, istruzione/occupazione 0) sono trattati come mancanti
* PRIMA della media, cosi' non contaminano i NIL vicini.
*
* Input:  $WORK/gentrif_nil.dta (NIL vecchi), $AUX/xw_nilold_nilnew.csv
* Output: $WORK/gentrif_nilnew.dta (NIL vigenti), $TAB/gentrification_nil_vigenti.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "07b - MISURE DELL'INDICE SUI NIL VIGENTI" _n "{hline 78}"

global NILNEW_OK 0
if $IX_OK == 0 {
    di as error "  07b saltato: indice non disponibile"
    exit
}
capture confirm file "$AUX/xw_nilold_nilnew.csv"
if _rc {
    di as error "  07b saltato: manca $AUX/xw_nilold_nilnew.csv (modulo 10a)"
    exit
}
if "$XW_NILCOV" == "" global XW_NILCOV 0.80

* NIL vecchi: zeri sospetti -> mancanti
use "$WORK/gentrif_nil.dta", clear
foreach v in inc price edu emp {
    foreach t in 2011 2021 {
        quietly replace `v'`t' = . if `v'`t' == 0
    }
}
local cont G_social d_edu_std d_emp_std dI_common dI_eq dI_paper ///
    inc2011 inc2021 price2011 price2021 edu2011 edu2021 emp2011 emp2021 idx2011 idx2021
local keepc
foreach v of local cont {
    capture confirm variable `v'
    if !_rc local keepc `keepc' `v'
}
keep nil name_ix `keepc'
rename nil nil_old
tempfile old
save `old'

import delimited using "$AUX/xw_nilold_nilnew.csv", clear varnames(1)
keep nil_old nil w wmax
merge m:1 nil_old using `old', keep(master match) nogen

foreach v of local keepc {
    gen double num_`v' = w*`v'
    gen double den_`v' = w if !missing(`v')
}
* nome del NIL vecchio prevalente (per controllo)
gsort nil -w
by nil: gen str60 name_old_main = name_ix[1]
by nil: gen int nil_old_main = nil_old[1]
collapse (sum) num_* den_* (first) name_old_main nil_old_main wmax, by(nil)
foreach v of local keepc {
    gen double `v' = num_`v'/den_`v' if den_`v' >= $XW_NILCOV
    rename den_`v' cov_`v'
}
drop num_*
rename wmax xw_wmax
label variable xw_wmax "Quota del NIL vigente dal NIL vecchio prevalente"
label variable G_social "Upgrading sociale 2011-21 portato sul NIL vigente (pesi di superficie)"

gen byte valid_social = !missing(G_social)
gen byte valid_full   = !missing(inc2011, inc2021, price2011, price2021, edu2011, edu2021, emp2011, emp2021)
label variable valid_social "Istruzione e occupazione valide (copertura >= $XW_NILCOV)"
label variable valid_full   "Tutte e quattro le componenti valide (copertura >= $XW_NILCOV)"

di as txt "  NIL vigenti: " _N
quietly count if valid_social
di as txt "  con G_social: " r(N) ";  con tutte le componenti: " _c
quietly count if valid_full
di as txt r(N)
di as txt "  Distribuzione della quota dal NIL vecchio prevalente:"
summarize xw_wmax, detail

* confronto con l'abbinamento per numero usato prima
preserve
use "$WORK/gentrif_nil.dta", clear
keep nil G_social
rename G_social G_social_bycode
tempfile bc
save `bc'
restore
merge 1:1 nil using `bc', keep(master match) nogen
gen double diffG = G_social - G_social_bycode
di as txt "  Differenza tra G_social sul NIL vigente e abbinamento per numero (prima):"
summarize diffG, detail
list nil name_old_main xw_wmax G_social_bycode G_social if abs(diffG) > 0.25 & !missing(diffG), noobs
drop G_social_bycode diffG

order nil nil_old_main name_old_main xw_wmax valid_social valid_full G_social
sort nil
save "$WORK/gentrif_nilnew.dta", replace
export delimited using "$TAB/gentrification_nil_vigenti.csv", replace
global NILNEW_OK 1
